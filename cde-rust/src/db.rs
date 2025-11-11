use anyhow::Result;
use redb::{Database, ReadableTable, TableDefinition};
use std::path::PathBuf;

const CACHE_TABLE: TableDefinition<&str, &str> = TableDefinition::new("cache");

fn db_path() -> Result<PathBuf> {
    let home = home::home_dir().ok_or_else(|| anyhow::anyhow!("Could not find home directory"))?;
    let db_dir = home.join(".local/share/cde");
    std::fs::create_dir_all(&db_dir)?;
    Ok(db_dir.join("cde.db"))
}

pub fn get_db() -> Result<Database> {
    let path = db_path()?;
    let db = Database::create(path)?;
    Ok(db)
}

pub fn set_cache(key: &str, value: &str) -> Result<()> {
    let db = get_db()?;
    let write_txn = db.begin_write()?;
    {
        let mut table = write_txn.open_table(CACHE_TABLE)?;
        table.insert(key, value)?;
    }
    write_txn.commit()?;
    Ok(())
}

pub fn show_cache() -> Result<()> {
    let db = get_db()?;
    let read_txn = db.begin_read()?;
    let table = read_txn.open_table(CACHE_TABLE)?;

    println!("📦 Cached data:\n");

    let mut count = 0;
    for entry in table.iter()? {
        let (key, value) = entry?;
        println!("  {} = {}", key.value(), value.value());
        count += 1;
    }

    if count == 0 {
        println!("  (no cached data)");
    }

    Ok(())
}

pub fn clean_cache() -> Result<()> {
    let path = db_path()?;
    if path.exists() {
        std::fs::remove_file(&path)?;
        println!("✅ Cache cleaned");
    } else {
        println!("✅ Cache already empty");
    }
    Ok(())
}
