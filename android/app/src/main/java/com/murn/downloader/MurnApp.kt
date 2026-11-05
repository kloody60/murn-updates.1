package com.murn.downloader

import android.app.Application

class MurnApp : Application() {
    override fun onCreate() {
        super.onCreate()
        DownloadManager.init(this)
    }
}
