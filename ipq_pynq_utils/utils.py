import platform

def _parse_version_string(s):
    arr = [int(v) for v in s.split(".")]
    return arr + [0]*(3-len(arr))

def _compare_version_lt(a, b):
    if a[0] < b[0]:
        return True
    elif a[0] > b[0]:
        return False

    if a[1] < b[1]:
        return True
    elif a[1] > b[1]:
        return False

    if a[2] < b[2]:
        return True

    return False

_python_version = _parse_version_string(platform.python_version())

def python_version_lt(a):
    if isinstance(a, str):
        return _compare_version_lt(_python_version, _parse_version_string(a))
    else:
        return _compare_version_lt(_python_version, a)
