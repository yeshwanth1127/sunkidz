from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    # Database
    database_url: str = "postgresql://postgres:postgres@localhost:5432/sunkidz_lms"

    # JWT
    jwt_secret_key: str = "your-super-secret-key-change-in-production"
    jwt_algorithm: str = "HS256"
    jwt_access_token_expire_minutes: int = 60 * 24  # 24 hours

    # Default classes created for each branch
    default_branch_classes: tuple[str, ...] = ("Playschool", "1G1", "1G2", "1G3")
    normal_branch_classes: tuple[str, ...] = ("Nursery", "LKG", "UKG")

    # UltraMsg WhatsApp API
    ultramsg_api_url: str = "https://api.ultramsg.com"
    ultramsg_instance_id: str = ""
    ultramsg_auth_token: str = ""

    # OneSignal
    onesignal_app_id: str = ""
    onesignal_api_key: str = ""


    class Config:
        env_file = ".env"
        extra = "ignore"


settings = Settings()
