import io
import unittest
import zipfile

from update_goldens import update_archive


PNG = b"\x89PNG\r\n\x1a\n"


def archive(files):
    data = io.BytesIO()
    with zipfile.ZipFile(data, "w") as package:
        for name, value in files.items():
            package.writestr(name, PNG + value)
    return data.getvalue()


class ReviewedGoldenTests(unittest.TestCase):
    def test_preserves_other_images_even_if_the_run_changed_or_omitted_them(self):
        base = archive({"old.png": b"old", "stencil.png": b"reviewed", "retained.png": b"retained"})
        candidate = archive({"old.png": b"updated", "new.png": b"new", "stencil.png": b"different"})
        result, found, changed = update_archive(base, candidate, ["old.png", "new.png"])
        self.assertEqual(found, {"old.png", "new.png"})
        self.assertEqual(changed, ["new.png", "old.png"])
        with zipfile.ZipFile(io.BytesIO(result)) as package:
            self.assertEqual({n: package.read(n) for n in package.namelist()}, {
                "old.png": PNG + b"updated", "new.png": PNG + b"new",
                "stencil.png": PNG + b"reviewed", "retained.png": PNG + b"retained",
            })
        self.assertEqual(update_archive(base, candidate, ["old.png", "new.png"])[0], result)

    def test_keeps_unaffected_platform_archive_byte_identical(self):
        base = archive({"same.png": b"same"})
        result, found, changed = update_archive(base, base, ["other_platform.png", "same.png"])
        self.assertEqual((result, found, changed), (base, {"same.png"}, []))

    def test_missing_existing_approved_image_aborts(self):
        with self.assertRaisesRegex(ValueError, "missing.*stencil.png"):
            update_archive(archive({"stencil.png": b"old"}), archive({}), ["stencil.png"])
