# Decisions

Why the parts that could plausibly have gone another way went this way. Read
this before proposing anything structural.

## The estimates are measurements, not a model

The obvious way to answer "what quality fits 500 KB?" is a formula: bits per
pixel as a function of quality, fitted to typical photographs. It is fast, it
needs no machinery, and it is wrong by a factor of three on any image that is
not typical — a screenshot and a beach photograph do not compress alike, and the
person asking is asking about *their* image.

So there is a formula, but it is only a seed. `SizeModel` carries a per-image,
per-format multiplier learnt from real encodes, and every encode the application
performs — for the preview, for the batch, including the attempts that missed —
is fed back into it. With two measurements at different qualities it stops using
the seed curve at all and interpolates between what it measured, in log space,
because the underlying relationship is geometric.

The cost is the machinery that makes those measurements affordable, which is the
next decision.

## A long-lived worker isolate, not `Isolate.run` per estimate

Every measurement means decoding the source, resizing it and encoding it.
`package:image` is pure Dart: a 12 MP JPEG decode is a second or two. Doing that
through `Isolate.run` for each slider movement would re-decode the same image
every time, and the numbers would always be several seconds behind the controls
that produced them.

`PreviewWorker` keeps one decoded image resident. The first measurement pays for
the decode; every one after it is a resize and an encode. One image at a time —
caching more would mean holding several uncompressed camera-sized bitmaps, which
is hundreds of megabytes for pictures nobody is looking at.

The batch is different and does use `Isolate.run` per file: there the decode is
paid once per file anyway, and independent isolates are what let four files run
at once.

## Quality first, then dimensions

When a byte budget cannot be met at the requested settings, something has to
give. The order is the order a person would choose: quality comes down first,
and only when quality is spent do pixels go.

The recommendation engine stops suggesting quality at 40. Below that JPEG
artefacts stop being a trade-off and start being the subject of the picture, and
a smaller clean image is almost always the better answer — so that is what the
dimension hint offers instead. The batch itself may still go below 40, but only
after dimensions have already been reduced.

## The search is bracketed, not binary

A textbook binary search over quality 1–100 is seven encodes. At several seconds
each that is a minute per file. The size of a JPEG is roughly geometric in
quality, so one measurement is enough to *predict* the quality that lands on the
budget and jump straight there; the bracket — highest known to fit, lowest known
to miss — keeps each prediction honest and guarantees termination. It usually
lands in two or three encodes, and it is capped at six.

## `budgetMet` must agree with the disk

The estimator can be wrong; that is what "estimate" means. What must never
happen is the batch reporting success for a file that is over budget. Every file
is encoded and checked, and one that could not get there is written as small as
the pipeline managed and marked over budget in its row and in the summary.

Handing back the *largest* failure would be perverse — the user asked for small
— so the smallest attempt is what gets written.

## A source file is never overwritten

`OutputNaming.resolve` renames around every path in the current batch, whatever
the collision policy says. The scenario this exists for is somebody resizing a
folder of photographs in place, with the originals as their only copy, who
leaves the suffix field empty. "Replace it" replaces a previous *output*; it can
never replace an input.

## WebP is read and not written

`package:image` gained a WebP encoder, but a lossless one — `WebPEncoder` takes
no quality argument at all. Offering WebP as a target would mean offering a
format that silently ignores the quality slider and, on photographs, usually
produces a *larger* file than the JPEG it replaced. A real lossy encoder means
FFI to libwebp built for both platforms; that is a decision to take on its own
merits, not to slide in behind a menu entry.

The same reasoning covers PSD and the Netpbm family: readable, never a target.
Under "same as source" a file in one of those formats fails with a message
rather than being written as something else.

## Cancelling means "start no more"

An `Isolate.run` halfway through an encode cannot be killed without leaving a
half-written file behind. Cancel therefore stops the batch launching anything
further and lets the files in flight finish — a second or two with four in
flight, and the alternative is a corrupt image on somebody's disk.

## Quality stays live under "same as source"

Selecting "same as source" leaves the quality slider enabled even when the
*selected* file is a PNG, because a mixed queue probably contains JPEGs too and
greying the control because of whichever row the cursor is on would be wrong for
every other file. The preview is the exception: it describes one file, so it
omits "quality N" from its caption when that file's format has no quality knob.

## Windows is a real target

Every sibling in this suite gitignores `windows/` and treats it as a way to look
at the interface without a VM. Here both platforms are supported and both are
built by CI. The consequence worth knowing: `windows/runner/Runner.rc` carries
the company and product names that `path_provider` builds the settings directory
from, so changing those strings moves where preferences live.

## Not done yet

Packaging (`.deb`, AppImage, MSIX), update checks, a second locale, per-file
overrides of the shared target, and watched-folder automation. Each is a natural
follow-up; none is needed for the application to do the job it is for.
