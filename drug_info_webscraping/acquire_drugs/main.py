import asyncio

try:
    from .run_options import main_menu
except Exception:
    from run_options import main_menu


async def main():
    await main_menu()


if __name__ == "__main__":
    asyncio.run(main())