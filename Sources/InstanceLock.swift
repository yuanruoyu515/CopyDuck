import Foundation
import Darwin

// Hold the descriptor for the entire process lifetime. Never unlink a live lock:
// another process may already have opened the same inode.
final class InstanceLock {
    private let descriptor: Int32

    private init(descriptor: Int32) { self.descriptor = descriptor }

    static func acquire(at url: URL) throws -> InstanceLock? {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let descriptor = open(url.path, O_CREAT | O_RDWR | O_CLOEXEC, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        if flock(descriptor, LOCK_EX | LOCK_NB) != 0 {
            let failure = errno
            close(descriptor)
            if failure == EWOULDBLOCK || failure == EAGAIN { return nil }
            throw POSIXError(POSIXErrorCode(rawValue: failure) ?? .EIO)
        }
        return InstanceLock(descriptor: descriptor)
    }

    deinit { close(descriptor) }
}
