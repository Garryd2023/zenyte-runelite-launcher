/*
 * Copyright (c) 2022, Adam <Adam@sigterm.info>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice, this
 *    list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
package net.runelite.launcher;

import com.google.common.base.MoreObjects;
import com.google.common.escape.Escapers;
import com.google.gson.Gson;
import com.google.gson.JsonParseException;
import joptsimple.OptionSet;
import lombok.extern.slf4j.Slf4j;
import net.runelite.launcher.beans.Bootstrap;
import net.runelite.launcher.beans.Update;
import org.w3c.dom.Document;
import org.w3c.dom.Element;
import org.w3c.dom.Node;
import org.w3c.dom.NodeList;

import javax.annotation.Nonnull;
import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;
import java.io.*;
import java.nio.channels.FileChannel;
import java.nio.file.*;
import java.nio.file.attribute.BasicFileAttributes;
import java.time.Instant;
import java.time.LocalTime;
import java.time.ZoneId;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.concurrent.TimeUnit;
import java.util.stream.Collectors;

import static net.runelite.launcher.Constants.SERVER_NAME;
import static net.runelite.launcher.Launcher.*;

@Slf4j
class Updater
{
	private static final String LAUNCHER_SETTINGS = "settings.json";
	private static final String RUNELITE_APP = "/Applications/" + SERVER_NAME + ".app";

	static void update(Bootstrap bootstrap, OptionSet options, String[] args)
	{
		if (OS.getOs() == OS.OSType.Windows)
		{
			updateWindows(bootstrap, options, args);
		}
		else if (OS.getOs() == OS.OSType.MacOS)
		{
			updateMacos(bootstrap, options, args);
		}
	}

	private static void updateMacos(Bootstrap bootstrap, OptionSet options, String[] args)
	{
		ProcessHandle current = ProcessHandle.current();
		var command = current.info().command();
		if (command.isEmpty())
		{
			log.debug("Running process has no command");
			return;
		}

		Path path = Paths.get(command.get());

		// on macOS packr changes the cwd to the resource directory prior to launching the JVM,
		// causing current.info().command() to return /Applications/RuneLite.app/Contents/Resources/./RuneLite
		// despite the executable really being at /Applications/RuneLite.app/Contents/MacOS/RuneLite
		path = path.normalize()
			.resolveSibling(Path.of("..", "MacOS", path.getFileName().toString()))
			.normalize();

		if (!path.getFileName().toString().equals(LAUNCHER_EXECUTABLE_NAME_OSX) || !path.startsWith(RUNELITE_APP))
		{
			log.debug("Skipping update check due to not running from installer, command is {}",
				command.get());
			return;
		}

		log.debug("Running from installer");

		var newestUpdate = findAvailableUpdate(bootstrap);
		if (newestUpdate == null)
		{
			return;
		}

		final boolean noupdate = options.has("noupdate");
		if (noupdate)
		{
			log.info("Skipping update {} due to noupdate being set", newestUpdate.getVersion());
			return;
		}

		if (System.getenv("RUNELITE_UPGRADE") != null)
		{
			log.info("Skipping update {} due to launching from an upgrade", newestUpdate.getVersion());
			return;
		}

		var settings = loadSettings();
		var hours = 1 << Math.min(9, settings.lastUpdateAttemptNum); // 512 hours = ~21 days
		if (newestUpdate.getHash().equals(settings.lastUpdateHash)
			&& Instant.ofEpochMilli(settings.lastUpdateAttemptTime).isAfter(Instant.now().minus(hours, ChronoUnit.HOURS)))
		{
			log.info("Previous upgrade attempt to {} was at {} (backoff: {} hours), skipping", newestUpdate.getVersion(),
				// logback logs are in local time, so use that to match it
				LocalTime.from(Instant.ofEpochMilli(settings.lastUpdateAttemptTime).atZone(ZoneId.systemDefault())),
				hours);
			return;
		}

		// check if rollout allows this update
		// there is no installer on macos to write install_id, so just use random()
		if (newestUpdate.getRollout() > 0. && Math.random() > newestUpdate.getRollout())
		{
			log.info("Skipping update {} due to rollout", newestUpdate.getVersion());
			return;
		}

		// from here and below the update will be attempted. update settings early so a failed
		// download counts as an attempt.
		settings.lastUpdateAttemptTime = System.currentTimeMillis();
		settings.lastUpdateHash = newestUpdate.getHash();
		settings.lastUpdateAttemptNum++;
		saveSettings(settings);

		try
		{
			log.info("Downloading launcher {} from {}", newestUpdate.getVersion(), newestUpdate.getUrl());

			var file = Files.createTempFile("rlupdate", "dmg");
			try (OutputStream fout = Files.newOutputStream(file))
			{
				final var name = newestUpdate.getName();
				final var size = newestUpdate.getSize();
				try
				{
					download(newestUpdate.getUrl(), newestUpdate.getHash(), (completed) ->
							SplashScreen.stage(.07, 1., null, name, completed, size, true),
						fout);
				}
				catch (VerificationException e)
				{
					log.error("unable to verify update", e);
					file.toFile().delete();
					return;
				}
			}

			log.debug("Mounting dmg {}", file);

			var pb = new ProcessBuilder(
				"hdiutil",
				"attach",
				"-nobrowse",
				"-plist",
				file.toAbsolutePath().toString()
			);
			Process process = pb.start();
			if (!process.waitFor(5, TimeUnit.SECONDS))
			{
				// timeout
				process.destroy();
				log.error("timeout waiting for hdiutil to attach dmg");
				return;
			}
			if (process.exitValue() != 0)
			{
				log.error("error running hdiutil attach");
				return;
			}
			String mountPoint;
			try (var in = process.getInputStream())
			{
				mountPoint = parseHdiutilPlist(in);
			}

			// point of no return
			log.debug("Removing old install from {}", RUNELITE_APP);
			delete(Path.of(RUNELITE_APP));

			log.debug("Copying new install from {}", mountPoint);
			copy(Path.of(mountPoint, SERVER_NAME + ".app"), Path.of(RUNELITE_APP));

			log.debug("Unmounting dmg");
			pb = new ProcessBuilder(
				"hdiutil",
				"detach",
				mountPoint
			);
			pb.start();

			log.debug("Done! Launching...");

			List<String> launchCmd = new ArrayList<>(args.length + 1);
			launchCmd.add(path.toAbsolutePath().toString());
			launchCmd.addAll(Arrays.asList(args));
			pb = new ProcessBuilder(launchCmd);
			pb.environment().put("RUNELITE_UPGRADE", "1");
			pb.start();

			System.exit(0);
		}
		catch (Exception e)
		{
			log.error("error performing upgrade", e);
		}
	}

	static String parseHdiutilPlist(InputStream in) throws Exception
	{
		DocumentBuilderFactory dbf = DocumentBuilderFactory.newInstance();
		DocumentBuilder db = dbf.newDocumentBuilder();
		Document doc = db.parse(in);
		doc.getDocumentElement().normalize();

		Element plist = (Element) doc.getElementsByTagName("plist").item(0);
		Element dict = (Element) plist.getElementsByTagName("dict").item(0);
		Element arr = (Element) dict.getElementsByTagName("array").item(0);
		NodeList dicts = arr.getElementsByTagName("dict");
		for (int i = 0; i < dicts.getLength(); ++i)
		{
			NodeList dict2 = (NodeList) dicts.item(i);
			String lastKey = null;

			for (int j = 0; j < dict2.getLength(); ++j)
			{
				Node node = dict2.item(j);

				if (node.getNodeType() == Node.ELEMENT_NODE)
				{
					if (node.getNodeName().equals("key"))
					{
						lastKey = node.getTextContent();
					}
					else if (lastKey != null)
					{
						if (lastKey.equals("mount-point"))
						{
							return node.getTextContent();
						}

						lastKey = null;
					}
				}
			}
		}
		return null;
	}

	private static void updateWindows(Bootstrap bootstrap, OptionSet options, String[] args)
	{
		ProcessHandle current = ProcessHandle.current();
		if (current.info().command().isEmpty())
		{
			log.debug("Running process has no command");
			return;
		}

		String installLocation;

		try
		{
			installLocation = regQueryString("Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\" + SERVER_NAME + " Launcher_is1", "InstallLocation");
		}
		catch (UnsatisfiedLinkError | RuntimeException ex)
		{
			log.debug("Skipping update check, error querying install location", ex);
			return;
		}

		Path path = Paths.get(current.info().command().get());
		if (!path.startsWith(installLocation)
			|| !path.getFileName().toString().equals(LAUNCHER_EXECUTABLE_NAME_WIN))
		{
			log.debug("Skipping update check due to not running from installer, command is {}",
				current.info().command().get());
			return;
		}

		log.debug("Running from installer");

		var newestUpdate = findAvailableUpdate(bootstrap);
		if (newestUpdate == null)
		{
			return;
		}

		final boolean noupdate = options.has("noupdate");
		if (noupdate)
		{
			log.info("Skipping update {} due to noupdate being set", newestUpdate.getVersion());
			return;
		}

		if (System.getenv("RUNELITE_UPGRADE") != null)
		{
			log.info("Skipping update {} due to launching from an upgrade", newestUpdate.getVersion());
			return;
		}

		var settings = loadSettings();
		var hours = 1 << Math.min(9, settings.lastUpdateAttemptNum); // 512 hours = ~21 days
		if (newestUpdate.getHash().equals(settings.lastUpdateHash)
			&& Instant.ofEpochMilli(settings.lastUpdateAttemptTime).isAfter(Instant.now().minus(hours, ChronoUnit.HOURS)))
		{
			log.info("Previous upgrade attempt to {} was at {} (backoff: {} hours), skipping", newestUpdate.getVersion(),
				// logback logs are in local time, so use that to match it
				LocalTime.from(Instant.ofEpochMilli(settings.lastUpdateAttemptTime).atZone(ZoneId.systemDefault())),
				hours);
			return;
		}

		// the installer kills running RuneLite processes, so check that there are no others running
		List<ProcessHandle> allProcesses = ProcessHandle.allProcesses().collect(Collectors.toList());
		for (ProcessHandle ph : allProcesses)
		{
			if (ph.pid() == current.pid())
			{
				continue;
			}

			if (ph.info().command().equals(current.info().command()))
			{
				log.info("Skipping update {} due to {} process {}", newestUpdate.getVersion(), LAUNCHER_EXECUTABLE_NAME_WIN, ph);
				return;
			}
		}

		// check if rollout allows this update
		if (newestUpdate.getRollout() > 0. && installRollout() > newestUpdate.getRollout())
		{
			log.info("Skipping update {} due to rollout", newestUpdate.getVersion());
			return;
		}

		// from here and below the update will be attempted. update settings early so a failed
		// download counts as an attempt.
		settings.lastUpdateAttemptTime = System.currentTimeMillis();
		settings.lastUpdateHash = newestUpdate.getHash();
		settings.lastUpdateAttemptNum++;
		saveSettings(settings);

		try
		{
			log.info("Downloading launcher {} from {}", newestUpdate.getVersion(), newestUpdate.getUrl());

			var file = Files.createTempFile("rlupdate", "exe");
			try (OutputStream fout = Files.newOutputStream(file))
			{
				final var name = newestUpdate.getName();
				final var size = newestUpdate.getSize();
				try
				{
					download(newestUpdate.getUrl(), newestUpdate.getHash(), (completed) ->
							SplashScreen.stage(.07, 1., null, name, completed, size, true),
						fout);
				}
				catch (VerificationException e)
				{
					log.error("unable to verify update", e);
					file.toFile().delete();
					return;
				}
			}

			log.info("Launching installer version {}", newestUpdate.getVersion());

			var pb = new ProcessBuilder(
				file.toFile().getAbsolutePath(),
				"/SILENT"
			);
			var env = pb.environment();

			var argStr = new StringBuilder();
			var escaper = Escapers.builder()
				.addEscape('"', "\\\"")
				.build();
			for (var arg : args)
			{
				if (argStr.length() > 0)
				{
					argStr.append(' ');
				}
				if (arg.contains(" ") || arg.contains("\""))
				{
					argStr.append('"').append(escaper.escape(arg)).append('"');
				}
				else
				{
					argStr.append(arg);
				}
			}

			env.put("RUNELITE_UPGRADE", "1");
			env.put("RUNELITE_UPGRADE_PARAMS", argStr.toString());
			pb.start();

			System.exit(0);
		}
		catch (IOException e)
		{
			log.error("io error performing upgrade", e);
		}
	}

	private static Update findAvailableUpdate(Bootstrap bootstrap)
	{
		var updates = bootstrap.getUpdates();
		if (updates == null)
		{
			return null;
		}

		final var os = System.getProperty("os.name");
		final var arch = System.getProperty("os.arch");
		final var launcherVersion = LauncherProperties.getVersion();
		if (os == null || arch == null || launcherVersion == null)
		{
			return null;
		}

		Update newestUpdate = null;
		for (var update : updates)
		{
			var updateOs = OS.parseOs(update.getOs());
			if ((updateOs == OS.OSType.Other ? update.getOs().equals(os) : updateOs == OS.getOs()) &&
				(update.getArch() == null || arch.equals(update.getArch())) &&
				compareVersion(update.getVersion(), launcherVersion) > 0 &&
				(update.getMinimumVersion() == null || compareVersion(launcherVersion, update.getMinimumVersion()) >= 0) &&
				(newestUpdate == null || compareVersion(update.getVersion(), newestUpdate.getVersion()) > 0))
			{
				log.info("Update {} is available", update.getVersion());
				newestUpdate = update;
			}
		}

		return newestUpdate;
	}

	@Nonnull
	private static LauncherSettings loadSettings()
	{
		var settingsFile = new File(LAUNCHER_SETTINGS).getAbsoluteFile();
		try (var in = new InputStreamReader(new FileInputStream(settingsFile)))
		{
			var settings = new Gson()
				.fromJson(in, LauncherSettings.class);
			return MoreObjects.firstNonNull(settings, new LauncherSettings());
		}
		catch (FileNotFoundException ex)
		{
			log.debug("unable to load settings, file does not exist");
			return new LauncherSettings();
		}
		catch (IOException | JsonParseException e)
		{
			log.warn("unable to load settings", e);
			return new LauncherSettings();
		}
	}

	private static void saveSettings(LauncherSettings settings)
	{
		var settingsFile = new File(LAUNCHER_SETTINGS).getAbsoluteFile();

		try
		{
			File tmpFile = File.createTempFile(LAUNCHER_SETTINGS, "json");
			var gson = new Gson();

			try (FileOutputStream fout = new FileOutputStream(tmpFile);
				FileChannel channel = fout.getChannel();
				PrintWriter writer = new PrintWriter(fout))
			{
				channel.lock();
				writer.write(gson.toJson(settings));
				channel.force(true);
				// FileChannel.close() frees the lock
			}

			try
			{
				Files.move(tmpFile.toPath(), settingsFile.toPath(), StandardCopyOption.REPLACE_EXISTING, StandardCopyOption.ATOMIC_MOVE);
			}
			catch (AtomicMoveNotSupportedException ex)
			{
				log.debug("atomic move not supported", ex);
				Files.move(tmpFile.toPath(), settingsFile.toPath(), StandardCopyOption.REPLACE_EXISTING);
			}
		}
		catch (IOException e)
		{
			log.warn("error saving launcher settings!", e);
			settingsFile.delete();
		}
	}

	private static double installRollout()
	{
		try (var reader = new BufferedReader(new FileReader("install_id.txt")))
		{
			var line = reader.readLine();
			if (line != null)
			{
				line = line.trim();
				var i = Integer.parseInt(line);
				log.debug("Loaded install id {}", i);
				return (double) i / (double) Integer.MAX_VALUE;
			}
		}
		catch (IOException | NumberFormatException ex)
		{
			log.warn("unable to get install rollout", ex);
		}
		return Math.random();
	}

	// https://stackoverflow.com/a/27917071
	private static void delete(Path directory) throws IOException
	{
		Files.walkFileTree(directory, new SimpleFileVisitor<>()
		{
			@Override
			public FileVisitResult visitFile(Path file, BasicFileAttributes attrs) throws IOException
			{
				Files.delete(file);
				return FileVisitResult.CONTINUE;
			}

			@Override
			public FileVisitResult postVisitDirectory(Path dir, IOException exc) throws IOException
			{
				Files.delete(dir);
				return FileVisitResult.CONTINUE;
			}
		});
	}

	// https://stackoverflow.com/a/60621544
	private static void copy(Path source, Path target, CopyOption... options)
		throws IOException
	{
		Files.walkFileTree(source, new SimpleFileVisitor<>()
		{
			@Override
			public FileVisitResult preVisitDirectory(Path dir, BasicFileAttributes attrs)
				throws IOException
			{
				Files.createDirectories(target.resolve(source.relativize(dir).toString()));
				return FileVisitResult.CONTINUE;
			}

			@Override
			public FileVisitResult visitFile(Path file, BasicFileAttributes attrs)
				throws IOException
			{
				Files.copy(file, target.resolve(source.relativize(file).toString()), options);
				return FileVisitResult.CONTINUE;
			}
		});
	}
}