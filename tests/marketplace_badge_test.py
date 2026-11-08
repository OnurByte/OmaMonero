import importlib.util
from pathlib import Path
import unittest

SPEC = importlib.util.spec_from_file_location(
    "marketplace_badge", Path(__file__).resolve().parents[1] / "scripts/marketplace-badge.py"
)
badge = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(badge)


def payload(**overrides):
    plugin = {"views": 1669, "copies": 655, "hearts": 690, **overrides}
    return {"schemaVersion": 1, "plugins": {badge.PLUGIN_ID: plugin}}


class MarketplaceBadgeTests(unittest.TestCase):
    def test_renders_real_counts_deterministically(self):
        counts = badge.read_counts(payload())
        svg = badge.render(counts)
        self.assertIn("655 install command copies, 690 hearts, 1669 views", svg)
        self.assertEqual(svg, badge.render(counts))

    def test_width_grows_with_digits(self):
        small = badge.render(badge.read_counts(payload(views=1)))
        large = badge.render(badge.read_counts(payload(views=100000)))
        self.assertLess(int(small.split('"')[3]), int(large.split('"')[3]))

    def test_rejects_data_that_would_show_a_made_up_number(self):
        for bad in ({"schemaVersion": 2, "plugins": {}}, {"schemaVersion": 1, "plugins": {}}):
            with self.assertRaises((ValueError, KeyError)):
                badge.read_counts(bad)
        for value in (-1, True, "5", None):
            with self.assertRaises(ValueError):
                badge.read_counts(payload(views=value))


if __name__ == "__main__":
    unittest.main()
