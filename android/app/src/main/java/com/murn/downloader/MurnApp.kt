package com.murn.downloader

import android.app.Application

class MurnApp : Application() {
    override fun onCreate() {
        super.onCreate()
        Lang.init(this)
        DownloadManager.init(this)
    }
}
