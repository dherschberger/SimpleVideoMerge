# SimpleVideoMerge
Swift package that contains functionality related to merging video files together.

Some general notes:

The purpose of this is for myself to learn how to do this, but also as a simple tool to serve my own needs.
Often times a home camera or surveilance software will create video files that each have N minutes of footage in them.
To simplify sharing of files, I would like to quickly merge a set of them together into a single file.

Other use cases are merging screen capture videos or any set of short videos that could be played back-to-back without
any transitions.

Since I am currently learning the media APIs that Apple provides, I don't have specific plans for all of the exact functionality
to be implemented, and I will initially take a lot of shortcuts to speed up learning. Eventually I may transform this into
something more production ready.

I have a simple SwiftUI test app for Mac that I am using to invoke the functionality. It's mostly just a single button currently.

I am writing this at the moment using Xcode 16 beta 4, and it is based on numerous examples I found while searching
the internet. All of those examples were not using Async/Await and most contained some kind of bug.

I have only tested with up to five 1-minute video source files that are 4k@30 from a camera, so they are all the same orientation,
file type, dimensions, and so on. They did not include audio, but perhaps still had the audio track (not sure).

I only intend to use this in a Mac app, but I'll try to code it to work well on all Apple platforms, except maybe Apple Watch.
Probably doesn't make sense to do this on Apple Watch due to the power required.
