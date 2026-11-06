package com.murn.downloader

enum class Status { RESOLVING, QUEUED, RUNNING, PAUSED, DONE, FAILED, CANCELED }

/** What the user wants out of each link. [height] = max video height (null = best available). */
enum class Quality(private val ar: String, private val en: String, val audioFormat: String? = null, val height: Int? = null) {
    BEST("أعلى جودة متاحة", "Best available"),
    P4320("8K (4320p)", "8K (4320p)", height = 4320),
    P2160("4K (2160p)", "4K (2160p)", height = 2160),
    P1440("2K (1440p)", "2K (1440p)", height = 1440),
    P1080("1080p", "1080p", height = 1080),
    P720("720p", "720p", height = 720),
    P480("480p", "480p", height = 480),
    MP3("صوت فقط (MP3)", "Audio only (MP3)", audioFormat = "mp3"),
    M4A("صوت فقط (M4A)", "Audio only (M4A)", audioFormat = "m4a");
    val label: String get() = tr(ar, en)
}

/** One video found in a link / page / search, before the user picked it. */
data class Candidate(
    val url: String, val title: String, val thumb: String?, val group: String?,
    /** a picture (downloaded directly), not a video */
    val isImage: Boolean = false,
    val referer: String? = null,
)

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
    /** real size of the downloaded video, e.g. "720p (720x1280)" */
    val resolution: String? = null,
    /** the video came out clearly smaller than the quality the user chose */
    val lowRes: Boolean = false,
    val image: Boolean = false,
    val referer: String? = null,
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
    /** more pages can be loaded ("load more") */
    val canMore: Boolean = false,
    val loading: Boolean = false,
    /** changes when the list is reloaded from scratch, so the picker resets its selection */
    val rev: Int = 0,
    val note: String? = null,
)
