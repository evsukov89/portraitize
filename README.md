# `portraitize` - OS X batch processing tool to extract portrait photos

Powered by `CIFaceFeature` from `CoreImage.framework`, this tool will batch scan input directory for images with faces and then extract those into output directory with specified image resolution.

## Usage

```bash
./portraitize <input-dir> <output-dir>
```

For every image in `<input-dir>` `portraitize` will scan for faces, if present – it will extract that part of an image, crop/resize and save with the same filename.

## Issues

* since result filename is exactly the same as source filename, if photo has multiple faces `portraitize` will essentially only save the latest recognized face
* output file size can only be changed in source code
* face size adjustment can only be changed in source code. This feature is required because `CIFaceDetector` only returns the face boundaries, but usually you also need to capture some space around for hair and shirt/jacket.
* all images saved as `jpeg`s, no matter of file extension.

## Compilaion

Make sure that you have `Command Line Tools` or `Xcode` installed

```bash
make
```

To debug, use

```base
make debug
```

You can put custom `lldb` commands into `.lldbinit` 
