#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <AppKit/AppKit.h>

#include <getopt.h>

#pragma mark DEFINES
#define APPVERSION @"0.2.1"

#pragma mark helper function definitions
static void PrintLn(NSString *format, ...) NS_FORMAT_FUNCTION(1,2);
static BOOL CheckIfDirecoryExists(NSFileManager *fm, NSString *dirPath);
static NSRect MultiplyRectBySizePercentage(NSRect rect, NSSize size);
static CGAffineTransform MakeScaleTransformFromSizes(NSSize currentSize, NSSize targetSize);

#pragma mark -
int main(int argc, char **argv) {
    @autoreleasepool {

    NSString *inputDirPath = nil, *outputDirPath = nil;
    NSSize faceImageSize = NSMakeSize(120, 120);
    NSSize faceRectMultiplicator = NSMakeSize(0.4, 0.7);
    NSBitmapImageFileType fileFormat = NSJPEGFileType;
    NSString *fileExtension = @"jpg";

    struct option long_options[] = {
       {"version",       no_argument,       NULL, 'v'},
       {"help",          no_argument,       NULL, 'h'},
       {"input",         required_argument, NULL, 'i'},
       {"output",        required_argument, NULL, 'o'},
       {"size",          optional_argument, NULL, 's'},
       {"multiplicator", optional_argument, NULL, 'm'},
       {"format",        optional_argument, NULL, 'f'},
       {NULL,            no_argument,       NULL,  0 }
    };
    int opt = 0, long_index = 0;
    while ((opt = getopt_long(argc, argv, "vhi:o:s:m:f:",  long_options, &long_index )) != -1) {
        switch( opt ) {
            case 'v':
                PrintLn(@"%@", APPVERSION);
                exit(0);
                break;
            case 'h':
                PrintLn(@"Usage: portraitize -i <input-dir> -o <output-dir>");
                exit(0);
                break;
            case 'i':
                inputDirPath = [[[NSString alloc] initWithUTF8String:optarg] stringByStandardizingPath];
                break;
            case 'o':
                outputDirPath = [[[NSString alloc] initWithUTF8String:optarg] stringByStandardizingPath];
                break;
            case 's': {
                NSString *sizeString = [[NSString alloc] initWithUTF8String:optarg];
                NSArray *sizeComponents = [sizeString componentsSeparatedByString:@"x"];
                if (sizeComponents.count >= 2) {
                    faceImageSize = NSMakeSize([sizeComponents[0] floatValue], 
                                               [sizeComponents[1] floatValue]);
                } else {
                    PrintLn(@"WARN: failed to parse size param: %@; using default", sizeString);
                }
                break;
            }
            case 'm': {
                NSString *multiplicatorString = [[NSString alloc] initWithUTF8String:optarg];
                NSArray *multiplicatorComponents = [multiplicatorString componentsSeparatedByString:@"x"];
                if (multiplicatorComponents.count >= 2) {
                    faceRectMultiplicator = NSMakeSize([multiplicatorComponents[0] floatValue]/100, 
                                                       [multiplicatorComponents[1] floatValue]/100);
                } else {
                    PrintLn(@"WARN: failed to parse multiplicator param: %@; using default", multiplicatorString);
                }
                break;
            }
            case 'f': {
                NSString *formatString = [[NSString alloc] initWithUTF8String:optarg];

                if ([formatString isEqual:@"tiff"]) {
                    fileFormat = NSTIFFFileType;
                    fileExtension = @"tiff";
                } else if ([formatString isEqual:@"bmp"]) {
                    fileFormat = NSBMPFileType;
                    fileExtension = @"bmp";
                } else if ([formatString isEqual:@"gif"]) {
                    fileFormat = NSGIFFileType;
                    fileExtension = @"gif";
                } else if ([formatString isEqual:@"jpeg"] || [formatString isEqual:@"jpg"]) {
                    fileFormat = NSJPEGFileType;
                    fileExtension = @"jpg";
                } else if ([formatString isEqual:@"png"]) {
                    fileFormat = NSPNGFileType;
                    fileExtension = @"png";
                }
            }
        }
    }

    if (!inputDirPath) {
        PrintLn(@"ERROR: missing input dir parameter");
        exit(1);
    }
    if (!outputDirPath) {
        PrintLn(@"ERROR: missing output dir parameter");
        exit(1);
    }

    PrintLn(@"processing: %@ -> %@, size: %@, multiplicator: %@, format: %@", 
        inputDirPath, outputDirPath, NSStringFromSize(faceImageSize), 
        NSStringFromSize(faceRectMultiplicator), fileExtension);

    NSFileManager *fm = [NSFileManager defaultManager];
    if (!CheckIfDirecoryExists(fm, inputDirPath)) {
        PrintLn(@"ERROR: \"%@\" doesn't exists or not a directory", inputDirPath);
    }

    NSError *outputDirCheckError = nil;
    BOOL outputDirPresent = [fm createDirectoryAtPath:outputDirPath withIntermediateDirectories:YES attributes:nil error:&outputDirCheckError];
    if (!outputDirPresent || outputDirCheckError) {
        PrintLn(@"ERROR: failed to create output directory: %@", outputDirCheckError);
    }

    NSError *inputEnumError = nil;
    NSArray *inputItems = [fm contentsOfDirectoryAtPath:inputDirPath error:&inputEnumError];
    if (inputEnumError) {
        PrintLn(@"ERROR: cannot get contents of input dir: %@", inputEnumError);
        exit(1);
    }

    NSDictionary *detectorOptions = @{ CIDetectorAccuracy: CIDetectorAccuracyHigh };
    CIDetector *faceDetector = [CIDetector detectorOfType:CIDetectorTypeFace context:nil options:detectorOptions];

    [inputItems enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop){
        NSString *inputFilePath = [inputDirPath stringByAppendingPathComponent:obj];
        
        BOOL inputFileIsDirectory = NO;
        [fm fileExistsAtPath:inputFilePath isDirectory:&inputFileIsDirectory];
        if (inputFileIsDirectory) {
            PrintLn(@"%lu. %@: is directory, skipping", (idx+1), obj);
            return;             
        }

        NSURL *inputFileURL = [NSURL fileURLWithPath:inputFilePath isDirectory:NO];
        CIImage *inputImage = [CIImage imageWithContentsOfURL:inputFileURL];
        if (!inputImage) { 
            PrintLn(@"%lu. %@: cannot read image", (idx+1), obj);
            return; 
        }
        // PrintLn(@"inputImage: %@", inputImage);
        
        NSArray *detectedFeatures = [faceDetector featuresInImage:inputImage];
        PrintLn(@"%lu. %@: faces detected: %lu", (idx+1), obj, detectedFeatures.count);
        [detectedFeatures enumerateObjectsUsingBlock:^(id detectedFeature, NSUInteger idx, BOOL *stop){
            if (![detectedFeature isKindOfClass:[CIFaceFeature class]]) { return; }

            @autoreleasepool {

            CIFaceFeature *faceFeature = detectedFeature;
            NSRect faceRect = MultiplyRectBySizePercentage(faceFeature.bounds, faceRectMultiplicator);

            CIImage *croppedInputImage = [inputImage imageByCroppingToRect:faceRect];

            CGAffineTransform resizeTransform = MakeScaleTransformFromSizes(faceRect.size, faceImageSize);
            CIImage *resizedInputImage = [croppedInputImage imageByApplyingTransform:resizeTransform];
            
            NSBitmapImageRep *croppedInputImageRep = [[NSBitmapImageRep alloc] initWithCIImage:resizedInputImage];

            NSData *croppedInputImageData = [croppedInputImageRep representationUsingType:fileFormat properties:nil];

            NSString *outFilename = obj;
            {
                NSArray *components = [obj componentsSeparatedByString:@"."];
                if (components.count > 1) {
                    NSArray *subarray = [components subarrayWithRange:NSMakeRange(0, components.count - 1)];
                    outFilename = [@[ [subarray componentsJoinedByString:@"."], fileExtension] componentsJoinedByString:@"."];
                }
            }

            NSString *outFilePath = [outputDirPath stringByAppendingPathComponent:outFilename];

            NSError *saveError = nil;
            BOOL saved = [croppedInputImageData writeToFile:outFilePath options:NSDataWritingAtomic error:&saveError];
            if (!saved || saveError) {
                PrintLn(@"%@: failed to save face image: %@", obj, saveError);
            }

            }
        }];
    }];

    }
    return 0;
}

#pragma mark helper functions

static void PrintLn(NSString *format, ...) {
    va_list arguments;
    va_start(arguments, format);
    NSString* s0 = [[NSString alloc] initWithFormat:format arguments:arguments];
    va_end(arguments);
    printf("%s\n", [s0 UTF8String]);
}

static BOOL CheckIfDirecoryExists(NSFileManager *fm, NSString *dirPath) {
    BOOL dirIsDirectory = NO;
    BOOL dirExists = [fm fileExistsAtPath:dirPath isDirectory:&dirIsDirectory];
    if (!dirExists) { return NO; }
    if (!dirIsDirectory) { return NO; }
    return YES;
}

static NSRect MultiplyRectBySizePercentage(NSRect rect, NSSize size) {
    NSRect newRect = rect;

    newRect.size.width = rect.size.width * (1 + size.width);
    newRect.origin.x -= (newRect.size.width - rect.size.width)/2;

    newRect.size.height = rect.size.height * (1 + size.height);
    newRect.origin.y -= (newRect.size.height - rect.size.height)/2;

    // PrintLn(@"%@ –> %@", NSStringFromRect(rect), NSStringFromRect(newRect));

    return newRect;
}

static CGAffineTransform MakeScaleTransformFromSizes(NSSize currentSize, NSSize targetSize) {
    CGSize scaledSize = targetSize;
    CGFloat scaleFactor = 1.f;
    if( currentSize.width > currentSize.height ) {
        scaleFactor = currentSize.width / currentSize.height;
        scaledSize.width = targetSize.width;
        scaledSize.height = targetSize.height / scaleFactor;
    }
    else {
        scaleFactor = currentSize.height / currentSize.width;
        scaledSize.height = targetSize.height;
        scaledSize.width = targetSize.width / scaleFactor;
    }

    CGFloat sx = 1;
    if (currentSize.width > scaledSize.width) {
        sx = scaledSize.width / currentSize.width;
    } else {
        sx = currentSize.width / scaledSize.width;
    }

    CGFloat sy = 1;
    if (currentSize.height > scaledSize.height) {
        sy = scaledSize.height / currentSize.height;
    } else {
        sy = currentSize.height / scaledSize.height;
    }

    CGAffineTransform transform = CGAffineTransformMakeScale(sx, sy);
    return transform;
}
