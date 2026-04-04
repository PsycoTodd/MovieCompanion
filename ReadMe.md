# Movie Compainion

This is an iOS app that you can use to display subtitles when you watch movie in the theater. It provides a on-device audio detection module from iOS API that will find the current timestamp based on the conversation on the big screen, and auto sync the subtitle to the correct time.

This gives people who cannot understand the language of the movie a chance to enjoy the story in the theater.

## Features

* Auto search the subtitle in the movie, so you can be sure that the subtitle always sync with the movie.
* Dark theme to avoid interfering with other audiences.
* You manage your subtitle library from google drive (details below) with auto sync.
* No need to use wifi or data after sync the subtitle library.
* Audio detection only used for 30 seconds to detect offset timestamp.

## How to use

* open the app, set up your own subtitle library (instruction in the next section)
* Choose the movie you want to watch from the list.
* Choose the language.
* When movie start, you should click the play button when the producuer logo shows up, but it may not always be accurate.
* Since the subtitle has time stamp, it should match the audio with 0 delay, if you notice out of sync, click the mic button.
* The mic button starts flash to lisen to the audio (so you do better click when the real verbal communication occurs). It will try to find the right subtitle timestamp.
* If it fails the job, you can keep trying.

## Set up your own subtitle library

First, create a google drive folder and set it to *Anyone with the link can view* as the access level.

The app support str format subtitle. The format contains timestamp and the corresponding sentance. To play the subtitle in your own language, you need at least two str files for the same movie.
One in the language of the movie (currently only support English), and the other one in the language you can read.

Make sure the subtitle files name follow the format below:

<MovieTitle>_EN.srt
<MovieTitle>_CN.srt

for exmaple, if I want to display English or Chinese subtitle. Upload these files into the shared drive folder. In general, you can find resources for the original subtitle when the movie released for a few weeks, but you may need to translate it to your own language with some tools.

Then go to https://script.google.com, create a new project. Copy the script/MovieLibrarySync.js content into the scirpt, change the FOLDER_ID to the folder's ID you shared.

Then run *installTrigger* from the menu (right to the Debug menu), to install the script to run every 30 min, it should be enough for you to sync your subtitle before you go to the theater.

Or you can manually run *syncManifest* everytime you upload new subtitles.


Last, in your installed MovieCompanion app, click the gear icon, and paste the shared drive link, then you should see your subtitle shows up in the selection.


## Future work

-[ ] Support audio language switch based on the movie native language.
-[ ] Provide toolset to translate English subtitle to your perferred srt files so you only need to wait for English subtilte to be available.
-[ ] Support UX in different languages

I create this for personal use and we should be aware that subtitle is also the asset of a movie, so we should not distribute it. However, I do hope to see a way to release the subtitle so people can engjoy movie without the language barrier.
