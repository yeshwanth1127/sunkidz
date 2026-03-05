from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    # Database
    database_url: str = "postgresql://postgres:postgres@localhost:5432/sunkidz_lms"

    # JWT
    jwt_secret_key: str = "your-super-secret-key-change-in-production"
    jwt_algorithm: str = "HS256"
    jwt_access_token_expire_minutes: int = 60 * 24  # 24 hours

    # Default classes created for each branch
    default_branch_classes: tuple[str, ...] = ("playgroup", "ig1", "ig2", "ig3")

    class Config:
        env_file = ".env"
        extra = "ignore"


settings = Settings()
