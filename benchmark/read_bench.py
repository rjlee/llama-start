import sys, json

def main():
    if len(sys.argv) < 2:
        print("- -")
        return
    try:
        with open(sys.argv[1]) as f:
            data = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        print("- -")
        return

    if not isinstance(data, list) or len(data) < 2:
        print("- -")
        return

    tg = data[1].get("avg_ts", 0) if isinstance(data[1], dict) else 0
    pp = data[0].get("avg_ts", 0) if isinstance(data[0], dict) else 0

    if tg == 0 and pp == 0:
        print("- -")
    else:
        print("%.0f %.0f" % (tg, pp))

if __name__ == "__main__":
    main()
