import sqlite3

from sqlalchemy import create_engine, inspect, text

import database


def test_old_database_gets_new_columns(tmp_path):
    db_path = tmp_path / "old.db"
    connection = sqlite3.connect(db_path)
    connection.execute(
        "CREATE TABLE inventory_items (id INTEGER PRIMARY KEY, barcode VARCHAR NOT NULL, name VARCHAR NOT NULL, "
        "category VARCHAR, expiry_date DATE NOT NULL, created_at DATETIME DEFAULT (CURRENT_TIMESTAMP))"
    )
    connection.execute("INSERT INTO inventory_items (barcode, name, expiry_date) VALUES ('1', 'Süt', '2026-10-01')")
    connection.commit()
    connection.close()

    engine = create_engine(f"sqlite:///{db_path}")
    database.init_db(engine)
    database.init_db(engine)  # ikinci çalıştırma hata vermemeli

    columns = {column["name"] for column in inspect(engine).get_columns("inventory_items")}
    assert {"date_type", "quantity", "unit", "location", "status", "closed_at"} <= columns
    assert inspect(engine).has_table("products")

    with engine.connect() as conn:
        row = conn.execute(text("SELECT name, date_type, quantity, unit, location, status FROM inventory_items")).one()
    assert tuple(row) == ("Süt", "SKT", 1, "adet", "dolap", "active")
