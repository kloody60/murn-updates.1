package com.murn.downloader

enum class Status { RESOLVING, QUEUED, RUNNING, PAUSED, DONE, FAILED, CANCELED }

/** What the user wants out of each link. [height] = max video height (null = best available). */
enum class Quality(val label: String, val audioFormat: String? = null, val height: Int? = null) {
    BEST("أعلى جودة متاحة"),
    P4320("8K (4320p)", height = 4320),
    P2160("4K (2160p)", height = 2160),
    P1440("2K (1440p)", height = 1440),
    P1080("1080p", height = 1080),
    P720("720p", height = 720),
    P480("480p", height = 480),
    P360("360p - توفير بيانات", height = 360),
    P240("240p", height = 240),
    P144("144p", height = 144),
    MP3("صوت فقط (MP3)", audioFormat = "mp3"),
    M4A("صوت فقط (M4A)", audioFormat = "m4a"),
}

/** One video found in a link / page / search, before the user picked it. */
data class Candidate(val url: String, val title: String, val thumb: String?, val group: String?)

data class Item(
    val id: String,
    val url: String,
    val title: String,
    val status: Status,
    val quality: Quality,
    val group: String? = null,
    val batch: String = "",
    val zip: Boolean = false,
    val progress: Float = 0f,
    val info: String = "",
    val error: String? = null,
    val savedName: String? = null,
) {
    /** counts as "work still to do" (keeps the background service alive) */
    val active: Boolean get() = status == Status.RESOLVING || status == Status.QUEUED || status == Status.RUNNING
}

/** A list of videos waiting for the user to tick the ones to download (the thumbnail grid). */
data class PickerRequest(
    val id: String,
    val title: String,
    val candidates: List<Candidate>,
    val limit: Int,
    val quality: Quality,
    val zip: Boolean,
    val batch: String,
)
