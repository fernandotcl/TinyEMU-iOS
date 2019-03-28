//
//  EmulatorCore.m
//  TinyEMU-iOS
//
//  Created by Fernando Lemos on 3/24/19.
//
//  Refer to the LICENSE file for licensing information.
//

@import Darwin;

#import "EmulatorCore.h"


int temu_main(int argc, const char **argv);


static NSInteger consoleColumns = 80;
static NSInteger consoleRows = 25;

void console_get_size(void *opaque, int *pw, int *ph)
{
    *pw = (int)consoleColumns;
    *ph = (int)consoleRows;
}


@interface EmulatorCore ()

@property (nonatomic, copy) NSString *configPath;
@property (nonatomic) int inputDescriptor;
@property (nonatomic) dispatch_source_t outputSource;

@end


@implementation EmulatorCore

- (instancetype)initWithConfigPath:(NSString *)path
{
    self = [super init];
    if (self != nil) {
        self.configPath = path;
    }
    return self;
}

- (void)start
{
    int fds[2];
    int flags;

    // Replace stdin with a pipe
    if (pipe(fds) == -1) {
        [NSException raise:NSInternalInconsistencyException format:@"pipe() failed"];
    }
    if (dup2(fds[0], STDIN_FILENO) != STDIN_FILENO) {
        [NSException raise:NSInternalInconsistencyException format:@"dup2() failed"];
    }
    self.inputDescriptor = fds[1];

    // Replace stdout with a pipe
    if (pipe(fds) == -1) {
        [NSException raise:NSInternalInconsistencyException format:@"pipe() failed"];
    }
    flags = fcntl(fds[0], F_GETFL);
    if (flags == -1) {
        [NSException raise:NSInternalInconsistencyException format:@"fcntl() failed"];
    }
    if (fcntl(fds[0], F_SETFL, flags | O_NONBLOCK) == -1) {
        [NSException raise:NSInternalInconsistencyException format:@"fcntl() failed"];
    }
    if (dup2(fds[1], STDOUT_FILENO) != STDOUT_FILENO) {
        [NSException raise:NSInternalInconsistencyException format:@"dup2() failed"];
    }

    // Set that up to dispatch to the main queue
    self.outputSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ,
                                               (uintptr_t)fds[0],
                                               0,
                                               dispatch_get_main_queue());
    __weak EmulatorCore *weakSelf = self;
    dispatch_source_set_event_handler(self.outputSource, ^{
        int descriptor = (int)dispatch_source_get_handle(weakSelf.outputSource);
        uint8_t buf[1024];
        for (;;) {
            ssize_t len = read(descriptor, buf, sizeof(buf) - 1);
            if (len > 0) {
                [self.delegate emulatorCore:self didReceiveOutput:[NSData dataWithBytes:buf length:len]];
            }
            else if (len == 0 || (len == -1 && errno == EAGAIN)) {
                break;
            }
            else {
                [NSException raise:NSInternalInconsistencyException format:@"read() failed"];
            }
        }
    });
    dispatch_resume(self.outputSource);

    // Run the emulator in a separate queue
    NSString *configPathCopy = [self.configPath copy];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        const char *argv[2];
        argv[0] = "temu";
        argv[1] = configPathCopy.UTF8String;
        temu_main(2, &argv[0]);
    });
}

- (void)writeData:(NSData *)data
{
    ssize_t len = write(self.inputDescriptor, data.bytes, data.length);
    if (len != data.length) {
        [NSException raise:NSInternalInconsistencyException format:@"write() failed"];
    }
}

- (void)resizeWithColumns:(NSInteger)columns rows:(NSInteger)rows
{
    if (consoleColumns == columns && consoleRows == rows) return;

    consoleColumns = columns;
    consoleRows = rows;

    kill(getpid(), SIGWINCH);
}

@end
