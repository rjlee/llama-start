import sys, json

def main():
    if len(sys.argv) < 2:
        print("-")
        return
    try:
        with open(sys.argv[1]) as f:
            d = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        print("-")
        return

    if not isinstance(d, dict):
        print("-")
        return

    if "error" in d:
        print("-")
        return

    tg = d.get("tg", 0)
    if tg == 0:
        print("-")
    else:
        print("%.0f" % tg)

if __name__ == "__main__":
    main()
