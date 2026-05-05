import unittest
from scripts.notion.block_diff import plan_diff

class TestListDiff(unittest.TestCase):
    def test_bulleted_list_edit(self):
        old = [{"id": "b1", "type": "bulleted_list_item", "bulleted_list_item": {"rich_text": [{"text": {"content": "Item A"}}]}}]
        new = [{"type": "bulleted_list_item", "bulleted_list_item": {"rich_text": [{"text": {"content": "Item A Revised"}}]}}]
        plan = plan_diff(old, new)
        self.assertEqual(plan.counts["update"], 1)

    def test_numbered_list_edit(self):
        old = [{"id": "b2", "type": "numbered_list_item", "numbered_list_item": {"rich_text": [{"text": {"content": "1. Item"}}]}}]
        new = [{"type": "numbered_list_item", "numbered_list_item": {"rich_text": [{"text": {"content": "1. Item Revised"}}]}}]
        plan = plan_diff(old, new)
        self.assertEqual(plan.counts["update"], 1)

    def test_mismatched_list_kind(self):
        old = [{"id": "b1", "type": "bulleted_list_item", "bulleted_list_item": {"rich_text": [{"text": {"content": "Item"}}]}}]
        new = [{"type": "numbered_list_item", "numbered_list_item": {"rich_text": [{"text": {"content": "Item"}}]}}]
        plan = plan_diff(old, new)
        self.assertEqual(plan.counts["update"], 0)
        # Should either be fallback or delete/append depending on policy
        self.assertTrue(plan.counts["fallback"] >= 1 or (plan.counts["delete"] > 0 and plan.counts["append"] > 0))

if __name__ == '__main__':
    unittest.main()
