#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <AppKit/AppKit.h>

void PrintLn(NSString *format, ...) {
    va_list arguments;
    va_start(arguments, format);
    NSString* s0 = [[NSString alloc] initWithFormat:format arguments:arguments];
    va_end(arguments);
    printf("%s\n", [s0 UTF8String]);
}

BOOL CheckIfDirecoryExists(NSFileManager *fm, NSString *dirPath) {
    BOOL dirIsDirectory = NO;
    BOOL dirExists = [fm fileExistsAtPath:dirPath isDirectory:&dirIsDirectory];
    if (!dirExists) { return NO; }
    if (!dirIsDirectory) { return NO; }
    return YES;
}

NSRect MultiplyRectBySizePercentage(NSRect rect, NSSize size) {
    NSRect newRect = rect;

    newRect.size.width = rect.size.width * (1 + size.width);
    newRect.origin.x -= (newRect.size.width - rect.size.width)/2;

    newRect.size.height = rect.size.height * (1 + size.height);
    newRect.origin.y -= (newRect.size.height - rect.size.height)/2;

    // PrintLn(@"%@ –> %@", NSStringFromRect(rect), NSStringFromRect(newRect));

    return newRect;
}

CGAffineTransform MakeScaleTransformFromSizes(NSSize currentSize, NSSize targetSize) {
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

int main(int argc, char **argv) {
    NSAutoreleasePool *pool = [NSAutoreleasePool new];

    NSProcessInfo *pi = [NSProcessInfo processInfo];

    if (pi.arguments.count < 2) {
        PrintLn(@"ERROR: please pass input and output directory ");
        exit(1);
    }

    NSString *inputDirPath = [pi.arguments[1] stringByStandardizingPath];
    NSString *outputDirPath = [pi.arguments[2] stringByStandardizingPath];
    PrintLn(@"processing: %@ -> %@", inputDirPath, outputDirPath);

    NSSize faceRectMultiplicator = NSMakeSize(0.8, 0.8);
    NSSize faceImageSize = NSMakeSize(120, 120);

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

            NSAutoreleasePool *pool = [NSAutoreleasePool new];

            CIFaceFeature *faceFeature = detectedFeature;
            NSRect faceRect = MultiplyRectBySizePercentage(faceFeature.bounds, faceRectMultiplicator);

            CIImage *croppedInputImage = [inputImage imageByCroppingToRect:faceRect];

            CGAffineTransform resizeTransform = MakeScaleTransformFromSizes(faceRect.size, faceImageSize);
            CIImage *resizedInputImage = [croppedInputImage imageByApplyingTransform:resizeTransform];
            
            NSBitmapImageRep *croppedInputImageRep = [[[NSBitmapImageRep alloc] initWithCIImage:resizedInputImage] autorelease];

            NSData *croppedInputImageData = [croppedInputImageRep representationUsingType:NSJPEGFileType properties:nil];
            NSString *outFilePath = [outputDirPath stringByAppendingPathComponent:obj];

            NSError *saveError = nil;
            BOOL saved = [croppedInputImageData writeToFile:outFilePath options:NSDataWritingAtomic error:&saveError];
            if (!saved || saveError) {
                PrintLn(@"%@: failed to save face image: %@", obj, saveError);
            }

            [pool drain];
        }];
    }];

    [pool drain];
    return 0;
}
