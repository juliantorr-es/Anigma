import unittest
import json
import os
import tempfile
from unittest.mock import patch, MagicMock

# Assuming scripts.anigma_publish_notion_v2 can be imported
from scripts.anigma_publish_notion_v2 import SyncReport

class TestPublisherReport(unittest.TestCase):
    def test_sync_report_initialization(self):
        report = SyncReport("block-diff dry-run")
        self.assertEqual(report.mode, "block-diff dry-run")
        self.assertEqual(report.safety_result, "safe")
        self.assertEqual(report.pages["created"], 0)

    def test_merge_plan(self):
        report = SyncReport("block-diff live")
        class MockPlan:
            counts = {"update": 2, "fallback": 1}
            actions = [
                {"action": "update", "new_block": {"type": "paragraph"}},
                {"action": "fallback", "type": "unsupported_block"}
            ]
        
        report.merge_plan(MockPlan())
        self.assertEqual(report.blocks["updated"], 2)
        self.assertEqual(report.blocks["fallback_required"], 1)
        self.assertEqual(report.block_types["paragraph"], 1)
        self.assertEqual(report.block_types["unsupported"], 1)

    def test_to_dict(self):
        report = SyncReport("default page sync")
        data = report.to_dict()
        self.assertIn("mode", data)
        self.assertEqual(data["mode"], "default page sync")
        self.assertIn("pages", data)
        self.assertIn("blocks", data)
        self.assertIn("block_types", data)
        self.assertIn("tables", data)
        self.assertIn("destructive", data)
        self.assertIn("safety_result", data)

if __name__ == '__main__':
    unittest.main()
