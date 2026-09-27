from sqlalchemy import create_engine, inspect, text
from sqlalchemy.orm import DeclarativeBase, sessionmaker

import config

# SQLite geliştirme için yeterli. PostgreSQL'e geçmek için .env içinde
# DATABASE_URL=postgresql://user:password@host/dbname vermek yeterlidir.
_connect_args = {"check_same_thread": False} if config.DATABASE_URL.startswith("sqlite") else {}

engine = create_engine(config.DATABASE_URL, connect_args=_connect_args)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


class Base(DeclarativeBase):
    pass


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def init_db(bind=engine):
    import models  # noqa: F401  (tabloların Base'e kaydolması için)

    Base.metadata.create_all(bind=bind)
    _add_missing_columns(bind)


def _add_missing_columns(bind):
    """
    Eski sürümle oluşturulmuş veritabanına yeni eklenen kolonları ekler.
    create_all() var olan tabloları değiştirmediği için bu basit migrasyon gerekir.
    """
    inspector = inspect(bind)
    with bind.begin() as conn:
        for table in Base.metadata.sorted_tables:
            if not inspector.has_table(table.name):
                continue
            existing = {column["name"] for column in inspector.get_columns(table.name)}
            for column in table.columns:
                if column.name in existing:
                    continue
                ddl = f"ALTER TABLE {table.name} ADD COLUMN {column.name} {column.type.compile(dialect=bind.dialect)}"
                # Sadece sabit metin varsayılanları eklenir (SQLite ADD COLUMN, now() gibi
                # sabit olmayan varsayılanları kabul etmez)
                default = column.server_default.arg if column.server_default is not None else None
                if isinstance(default, str):
                    ddl += f" DEFAULT '{default}'"
                conn.execute(text(ddl))
