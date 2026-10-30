use crate::{Error, Result, state::snapshot::Snapshot};
use fs2::FileExt;
use std::{
    fs::{self, DirBuilder, File, OpenOptions},
    io::{Read, Write},
    os::unix::fs::{DirBuilderExt, MetadataExt, OpenOptionsExt, PermissionsExt},
    path::{Path, PathBuf},
};

// SAFETY: geteuid has no parameters and cannot fail; used only for ownership checks.
fn uid() -> u32 {
    unsafe { libc::geteuid() }
}
fn private_directory(path: &Path) -> Result<()> {
    let meta = fs::symlink_metadata(path).map_err(|_| Error::Runtime)?;
    if !path.is_absolute()
        || !meta.is_dir()
        || meta.file_type().is_symlink()
        || meta.uid() != uid()
        || meta.permissions().mode() & 0o077 != 0
    {
        return Err(Error::Runtime);
    }
    // Resolve ancestors, too: a symlink anywhere in the supplied runtime path is rejected.
    if fs::canonicalize(path).map_err(|_| Error::Runtime)? != path {
        return Err(Error::Runtime);
    }
    Ok(())
}
pub fn runtime_parent(override_path: Option<PathBuf>) -> Result<PathBuf> {
    let path = override_path
        .or_else(|| std::env::var_os("XDG_RUNTIME_DIR").map(PathBuf::from))
        .ok_or(Error::Runtime)?;
    private_directory(&path)?;
    Ok(path)
}
pub struct StateWriter {
    directory: PathBuf,
    _lock: File,
}
impl StateWriter {
    pub fn new(parent: &Path) -> Result<Self> {
        private_directory(parent)?;
        let directory = parent.join("omamonero");
        match DirBuilder::new().mode(0o700).create(&directory) {
            Ok(()) => {}
            Err(e) if e.kind() == std::io::ErrorKind::AlreadyExists => {}
            Err(_) => return Err(Error::Runtime),
        }
        private_directory(&directory)?;
        let lock = OpenOptions::new()
            .read(true)
            .write(true)
            .create(true)
            .truncate(false)
            .mode(0o600)
            .custom_flags(libc::O_NOFOLLOW | libc::O_NONBLOCK)
            .open(directory.join("backend.lock"))
            .map_err(|_| Error::State)?;
        let meta = lock.metadata().map_err(|_| Error::State)?;
        if !meta.is_file()
            || meta.uid() != uid()
            || meta.permissions().mode() & 0o777 != 0o600
            || meta.nlink() != 1
        {
            return Err(Error::State);
        }
        lock.try_lock_exclusive()
            .map_err(|_| Error::AlreadyRunning)?;
        Ok(Self {
            directory,
            _lock: lock,
        })
    }
    pub fn write(&self, snapshot: &Snapshot) -> Result<()> {
        let mut file = tempfile::Builder::new()
            .prefix(".status-")
            .tempfile_in(&self.directory)
            .map_err(|_| Error::State)?;
        file.as_file()
            .set_permissions(fs::Permissions::from_mode(0o600))
            .map_err(|_| Error::State)?;
        serde_json::to_writer(file.as_file_mut(), snapshot).map_err(|_| Error::State)?;
        file.write_all(b"\n").map_err(|_| Error::State)?;
        file.as_file().sync_all().map_err(|_| Error::State)?;
        file.persist(self.directory.join("status.json"))
            .map_err(|_| Error::State)?;
        File::open(&self.directory)
            .and_then(|f| f.sync_all())
            .map_err(|_| Error::State)?;
        Ok(())
    }
}
pub fn read(parent: &Path) -> Result<Option<Snapshot>> {
    private_directory(parent)?;
    let directory = parent.join("omamonero");
    if !directory.exists() {
        return Ok(None);
    }
    private_directory(&directory)?;
    let file = match OpenOptions::new()
        .read(true)
        .custom_flags(libc::O_NOFOLLOW | libc::O_NONBLOCK)
        .open(directory.join("status.json"))
    {
        Ok(f) => f,
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => return Ok(None),
        Err(_) => return Err(Error::State),
    };
    let meta = file.metadata().map_err(|_| Error::State)?;
    if !meta.is_file()
        || meta.uid() != uid()
        || meta.permissions().mode() & 0o777 != 0o600
        || meta.len() > 1048576
        || meta.nlink() != 1
    {
        return Err(Error::State);
    }
    let mut bytes = Vec::new();
    file.take(1048577)
        .read_to_end(&mut bytes)
        .map_err(|_| Error::State)?;
    if bytes.len() > 1048576 {
        return Err(Error::State);
    }
    serde_json::from_slice(&bytes)
        .map(Some)
        .map_err(|_| Error::State)
}
