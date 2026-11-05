package com.murn.downloader

enum class Status { RESOLVING, QUEUED, RUNNING, DONE, FAILED, CANCELED }

/** What the user wants out of each link. [height] = max video height (null = best available). */
enum class Quality(val label: String, val audioFormat: String? = null, val height: Int? = null) {
    BEST("أعلى جودة متاحة (MP4)"),
    P1080("1080p (MP4)", height = 1080),
    P720("720p (MP4)", height = 720),
    P480("480p (MP4)", height = 480),
    P360("360p (MP4) - توفير بيانات", height = 360),
    MP3("صوت فقط (MP3)", audioFormat = "mp3"),
    M4A("صوت فقط (M4A)", audioFormat = "m4a"),
}

data class Item(
    val id: String,
    val url: String,
    val title: String,
    val status: Status,
    val quality: Quality,
    val group: String? = null,
    val progress: Float = 0f,
    val info: String = "",
    val error: String? = null,
    val savedName: String? = null,
) {
    val active: Boolean get() = status == Status.RESOLVING || status == Status.QUEUED || status == Status.RUNNING
}
