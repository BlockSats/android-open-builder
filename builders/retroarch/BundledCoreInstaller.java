package com.retroarch.browser;

import com.retroarch.BuildConfig;

import android.content.Context;
import android.content.SharedPreferences;
import android.content.pm.ApplicationInfo;
import android.util.Log;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;

/** Installs cores shipped as native libraries into RetroArch's writable core directory. */
public final class BundledCoreInstaller
{
    private static final String TAG = "BundledCoreInstaller";
    private static final String PREFS_NAME = "aob_bundled_cores";
    private static final String REVISION_KEY = "fceumm_revision";
    private static final String NATIVE_LIBRARY_NAME = "libfceumm_libretro_android.so";
    private static final String CORE_FILE_NAME = "fceumm_libretro_android.so";

    private BundledCoreInstaller()
    {
    }

    public static void install(Context context)
    {
        ApplicationInfo appInfo = context.getApplicationInfo();
        File source = new File(appInfo.nativeLibraryDir, NATIVE_LIBRARY_NAME);
        File coreDir = new File(appInfo.dataDir, "cores");
        File destination = new File(coreDir, CORE_FILE_NAME);
        SharedPreferences prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        String installedRevision = prefs.getString(REVISION_KEY, "");

        if (!source.isFile())
        {
            Log.e(TAG, "Bundled FCEUmm native library is missing: " + source);
            return;
        }

        if (BuildConfig.BUNDLED_FCEUMM_REVISION.equals(installedRevision)
                && destination.isFile()
                && destination.length() == source.length())
            return;

        if (!coreDir.isDirectory() && !coreDir.mkdirs())
        {
            Log.e(TAG, "Could not create RetroArch core directory: " + coreDir);
            return;
        }

        File temporary = new File(coreDir, CORE_FILE_NAME + ".tmp");
        try
        {
            copyFile(source, temporary);

            if (destination.exists() && !destination.delete())
                throw new IOException("Could not replace existing core: " + destination);

            if (!temporary.renameTo(destination))
                throw new IOException("Could not install bundled core: " + destination);

            destination.setReadable(true, false);
            destination.setExecutable(true, false);
            prefs.edit().putString(REVISION_KEY, BuildConfig.BUNDLED_FCEUMM_REVISION).apply();
            Log.i(TAG, "Installed bundled FCEUmm core revision " + BuildConfig.BUNDLED_FCEUMM_REVISION);
        }
        catch (IOException exception)
        {
            temporary.delete();
            Log.e(TAG, "Could not install bundled FCEUmm core", exception);
        }
    }

    private static void copyFile(File source, File destination) throws IOException
    {
        byte[] buffer = new byte[64 * 1024];
        int count;

        try (FileInputStream input = new FileInputStream(source);
             FileOutputStream output = new FileOutputStream(destination))
        {
            while ((count = input.read(buffer)) != -1)
                output.write(buffer, 0, count);

            output.getFD().sync();
        }
    }
}
