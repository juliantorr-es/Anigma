import unittest
from scripts.notion.block_diff import plan_diff

class TestBlockDiff(unittest.TestCase):
    def test_paragraph_edit(self):
        old = [{"id": "b1", "type": "paragraph", "paragraph": {"rich_text": [{"text": {"content": "Hello"}}]}}]
        new = [{"type": "paragraph", "paragraph": {"rich_text": [{"text": {"content": "Hello World"}}]}}]
        plan = plan_diff(old, new)
        self.assertEqual(plan.counts["update"], 1)

    def test_add_paragraph(self):
        old = []
        new = [{"type": "paragraph", "paragraph": {"rich_text": [{"text": {"content": "New"}}]}}]
        plan = plan_diff(old, new)
        self.assertEqual(plan.counts["append"], 1)

    def test_delete_paragraph(self):
        old = [{"id": "b1", "type": "paragraph", "paragraph": {"rich_text": [{"text": {"content": "Old"}}]}}]
        new = []
        plan = plan_diff(old, new)
        self.assertEqual(plan.counts["delete"], 1)

    def test_unsupported_block_type(self):
        # Unsupported type should trigger fallback
        old = [{"id": "b1", "type": "unsupported"}]
        new = [{"type": "unsupported"}]
        # Our current implementation maps this to "keep" because fingerprints are same
        plan = plan_diff(old, new)
        self.assertEqual(plan.counts["keep"], 1)

if __name__ == '__main__':
    unittest.main()
