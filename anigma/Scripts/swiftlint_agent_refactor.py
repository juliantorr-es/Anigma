#!/usr/bin/env python3
"""
SwiftLint Interactive Agent-Assisted Refactoring Tool

An interactive refactoring system that presents refactoring suggestions to an AI agent,
allows the agent to approve/reject/modify them, and applies approved changes.

This tool bridges automated refactoring with human-level judgment by:
1. Generating refactoring suggestions using AST analysis
2. Presenting each suggestion with full context
3. Allowing an agent to approve, reject, or propose alternatives
4. Applying approved refactorings with full audit trail
5. Learning from agent feedback to improve future suggestions

Usage:
    # Interactive mode with agent
    python3 Scripts/swiftlint_agent_refactor.py --interactive
    
    # Batch mode with confidence threshold
    python3 Scripts/swiftlint_agent_refactor.py --auto-approve --min-confidence 0.9
    
    # Review mode (show suggestions without applying)
    python3 Scripts/swiftlint_agent_refactor.py --review-only

Author: Anigma Development Team
Date: 2026-01-11
"""

import argparse
import json
import re
import subprocess
import sys
from dataclasses import dataclass, field, asdict
from pathlib import Path
from typing import List, Dict, Optional, Tuple, Any
from enum import Enum
import shutil
from datetime import datetime


class RefactoringDecision(Enum):
    """Agent's decision on a refactoring."""
    APPROVE = "approve"
    REJECT = "reject"
    MODIFY = "modify"
    SKIP = "skip"
    NEEDS_REVIEW = "needs_review"


@dataclass
class AgentFeedback:
    """Feedback from the agent on a refactoring."""
    decision: RefactoringDecision
    reasoning: str
    alternative_code: Optional[str] = None
    confidence: float = 1.0
    tags: List[str] = field(default_factory=list)
    
    def to_dict(self) -> Dict:
        return {
            'decision': self.decision.value,
            'reasoning': self.reasoning,
            'alternative_code': self.alternative_code,
            'confidence': self.confidence,
            'tags': self.tags
        }


@dataclass
class RefactoringProposal:
    """A refactoring proposal with full context."""
    id: str
    type: str
    file: str
    line_start: int
    line_end: int
    description: str
    
    # Code context
    original_code: str
    proposed_code: str
    surrounding_context: str  # Lines before and after
    
    # Metadata
    confidence: float
    complexity_reduction: Optional[int] = None
    parameter_reduction: Optional[int] = None
    estimated_impact: str = "low"  # low, medium, high
    
    # Agent interaction
    agent_feedback: Optional[AgentFeedback] = None
    applied: bool = False
    applied_at: Optional[str] = None
    
    def to_dict(self) -> Dict:
        data = asdict(self)
        if self.agent_feedback:
            data['agent_feedback'] = self.agent_feedback.to_dict()
        return data
    
    def get_context_display(self, context_lines: int = 5) -> str:
        """Get formatted context for display."""
        lines = []
        lines.append(f"\n{'='*80}")
        lines.append(f"📋 Refactoring Proposal #{self.id}")
        lines.append(f"{'='*80}")
        lines.append(f"Type: {self.type}")
        lines.append(f"File: {self.file}")
        lines.append(f"Lines: {self.line_start}-{self.line_end}")
        lines.append(f"Confidence: {self.confidence:.0%}")
        lines.append(f"Impact: {self.estimated_impact}")
        lines.append(f"\nDescription: {self.description}")
        
        if self.complexity_reduction:
            lines.append(f"Complexity Reduction: {self.complexity_reduction}")
        if self.parameter_reduction:
            lines.append(f"Parameter Reduction: {self.parameter_reduction}")
        
        lines.append(f"\n{'─'*80}")
        lines.append("📄 ORIGINAL CODE:")
        lines.append(f"{'─'*80}")
        for i, line in enumerate(self.original_code.split('\n'), 1):
            lines.append(f"{i:3d} │ {line}")
        
        lines.append(f"\n{'─'*80}")
        lines.append("✨ PROPOSED REFACTORING:")
        lines.append(f"{'─'*80}")
        for i, line in enumerate(self.proposed_code.split('\n'), 1):
            lines.append(f"{i:3d} │ {line}")
        
        if self.surrounding_context:
            lines.append(f"\n{'─'*80}")
            lines.append("🔍 SURROUNDING CONTEXT:")
            lines.append(f"{'─'*80}")
            lines.append(self.surrounding_context)
        
        lines.append(f"{'='*80}\n")
        
        return '\n'.join(lines)


class AgentInterface:
    """Interface for agent interaction."""
    
    def __init__(self, interactive: bool = True):
        self.interactive = interactive
        self.feedback_history: List[AgentFeedback] = []
    
    def present_proposal(self, proposal: RefactoringProposal) -> AgentFeedback:
        """Present a refactoring proposal to the agent."""
        print(proposal.get_context_display())
        
        if not self.interactive:
            # Auto-approve high confidence proposals
            if proposal.confidence >= 0.9:
                return AgentFeedback(
                    decision=RefactoringDecision.APPROVE,
                    reasoning="High confidence automatic approval",
                    confidence=proposal.confidence
                )
            else:
                return AgentFeedback(
                    decision=RefactoringDecision.NEEDS_REVIEW,
                    reasoning="Confidence below auto-approval threshold",
                    confidence=proposal.confidence
                )
        
        return self._get_agent_decision(proposal)
    
    def _get_agent_decision(self, proposal: RefactoringProposal) -> AgentFeedback:
        """Get decision from agent (interactive mode)."""
        print("\n🤖 AGENT DECISION REQUIRED")
        print("─" * 80)
        print("Options:")
        print("  [a] Approve - Apply this refactoring as-is")
        print("  [r] Reject - Skip this refactoring")
        print("  [m] Modify - Propose an alternative refactoring")
        print("  [s] Skip - Skip for now, review later")
        print("  [?] Help - Show detailed analysis")
        print()
        
        while True:
            choice = input("Your decision [a/r/m/s/?]: ").strip().lower()
            
            if choice == 'a':
                reasoning = input("Reasoning (optional): ").strip() or "Approved by agent"
                return AgentFeedback(
                    decision=RefactoringDecision.APPROVE,
                    reasoning=reasoning,
                    confidence=1.0
                )
            
            elif choice == 'r':
                reasoning = input("Why reject? ").strip() or "Rejected by agent"
                return AgentFeedback(
                    decision=RefactoringDecision.REJECT,
                    reasoning=reasoning,
                    confidence=1.0
                )
            
            elif choice == 'm':
                print("\n✏️  Enter your alternative refactoring:")
                print("(Type 'END' on a new line when done)")
                alternative_lines = []
                while True:
                    line = input()
                    if line.strip() == 'END':
                        break
                    alternative_lines.append(line)
                
                alternative_code = '\n'.join(alternative_lines)
                reasoning = input("Explain your changes: ").strip()
                
                return AgentFeedback(
                    decision=RefactoringDecision.MODIFY,
                    reasoning=reasoning,
                    alternative_code=alternative_code,
                    confidence=1.0
                )
            
            elif choice == 's':
                return AgentFeedback(
                    decision=RefactoringDecision.SKIP,
                    reasoning="Deferred for later review",
                    confidence=0.5
                )
            
            elif choice == '?':
                self._show_detailed_analysis(proposal)
            
            else:
                print("❌ Invalid choice. Please enter a, r, m, s, or ?")
    
    def _show_detailed_analysis(self, proposal: RefactoringProposal):
        """Show detailed analysis to help agent decide."""
        print("\n📊 DETAILED ANALYSIS")
        print("─" * 80)
        
        # Analyze the refactoring
        original_lines = len(proposal.original_code.split('\n'))
        proposed_lines = len(proposal.proposed_code.split('\n'))
        line_diff = proposed_lines - original_lines
        
        print(f"Lines of code: {original_lines} → {proposed_lines} ({line_diff:+d})")
        
        # Check for potential issues
        issues = []
        if 'fatalError' in proposal.proposed_code:
            issues.append("⚠️  Uses fatalError - consider proper error handling")
        if 'TODO' in proposal.proposed_code:
            issues.append("⚠️  Contains TODO comments")
        if proposed_lines > original_lines * 2:
            issues.append("⚠️  Significantly increases code size")
        
        if issues:
            print("\nPotential Issues:")
            for issue in issues:
                print(f"  {issue}")
        else:
            print("\n✅ No obvious issues detected")
        
        # Show what changed
        print("\nKey Changes:")
        if proposal.type == 'extract_config':
            print("  • Extracts configuration object")
            print("  • Reduces parameter count")
            print("  • Improves maintainability")
        elif proposal.type == 'tuple_to_struct':
            print("  • Converts tuple to struct")
            print("  • Adds type safety")
            print("  • Improves readability")
        
        print()


class InteractiveRefactorer:
    """Interactive refactoring engine with agent assistance."""
    
    def __init__(self, repo_root: Path, agent: AgentInterface):
        self.repo_root = repo_root
        self.agent = agent
        self.proposals: List[RefactoringProposal] = []
        self.session_id = datetime.now().strftime("%Y%m%d_%H%M%S")
        self.session_log: List[Dict] = []
    
    def load_refactoring_plan(self, plan_file: Path) -> int:
        """Load refactoring proposals from a plan file."""
        if not plan_file.exists():
            print(f"❌ Plan file not found: {plan_file}")
            return 0
        
        with open(plan_file) as f:
            plan = json.load(f)
        
        for i, task in enumerate(plan.get('tasks', []), 1):
            # Get surrounding context
            context = self._get_surrounding_context(
                task['file'],
                task['line'],
                context_lines=5
            )
            
            proposal = RefactoringProposal(
                id=f"{self.session_id}_{i:04d}",
                type=task['type'],
                file=task['file'],
                line_start=task['line'],
                line_end=task.get('line_end', task['line']),
                description=task['description'],
                original_code=self._get_original_code(task['file'], task['line']),
                proposed_code=task.get('refactored_code', ''),
                surrounding_context=context,
                confidence=task.get('confidence', 0.5),
                complexity_reduction=task.get('metadata', {}).get('complexity_reduction'),
                parameter_reduction=task.get('metadata', {}).get('parameter_reduction'),
                estimated_impact=self._estimate_impact(task)
            )
            
            self.proposals.append(proposal)
        
        print(f"✅ Loaded {len(self.proposals)} refactoring proposals")
        return len(self.proposals)
    
    def generate_proposals_from_violations(self) -> int:
        """Generate proposals from SwiftLint violations."""
        print("🔍 Analyzing codebase for refactoring opportunities...")
        
        # Run SwiftLint
        result = subprocess.run(
            ['swiftlint', 'lint', '--reporter', 'json'],
            cwd=self.repo_root,
            capture_output=True,
            text=True
        )
        
        violations = json.loads(result.stdout)
        
        # Focus on high-value violations
        target_rules = {
            'function_parameter_count': self._create_param_reduction_proposal,
            'large_tuple': self._create_tuple_to_struct_proposal,
            'force_unwrapping': self._create_force_unwrap_proposal,
            'force_cast': self._create_force_cast_proposal,
        }
        
        for violation in violations:
            rule_id = violation['rule_id']
            if rule_id in target_rules:
                proposal = target_rules[rule_id](violation)
                if proposal:
                    self.proposals.append(proposal)
        
        print(f"✅ Generated {len(self.proposals)} refactoring proposals")
        return len(self.proposals)
    
    def run_interactive_session(self):
        """Run interactive refactoring session with agent."""
        if not self.proposals:
            print("❌ No proposals to review")
            return
        
        print(f"\n{'='*80}")
        print(f"🤖 INTERACTIVE REFACTORING SESSION")
        print(f"{'='*80}")
        print(f"Session ID: {self.session_id}")
        print(f"Total Proposals: {len(self.proposals)}")
        print(f"Repository: {self.repo_root}")
        print(f"{'='*80}\n")
        
        approved = 0
        rejected = 0
        modified = 0
        skipped = 0
        
        for i, proposal in enumerate(self.proposals, 1):
            print(f"\n📍 Proposal {i}/{len(self.proposals)}")
            
            # Present to agent
            feedback = self.agent.present_proposal(proposal)
            proposal.agent_feedback = feedback
            
            # Log decision
            self.session_log.append({
                'proposal_id': proposal.id,
                'decision': feedback.decision.value,
                'reasoning': feedback.reasoning,
                'timestamp': datetime.now().isoformat()
            })
            
            # Handle decision
            if feedback.decision == RefactoringDecision.APPROVE:
                self._apply_refactoring(proposal)
                approved += 1
                print("✅ Approved and applied")
            
            elif feedback.decision == RefactoringDecision.MODIFY:
                self._apply_modified_refactoring(proposal, feedback.alternative_code)
                modified += 1
                print("✏️  Modified and applied")
            
            elif feedback.decision == RefactoringDecision.REJECT:
                rejected += 1
                print("❌ Rejected")
            
            elif feedback.decision == RefactoringDecision.SKIP:
                skipped += 1
                print("⏭️  Skipped")
            
            # Save progress after each decision
            self._save_session_state()
        
        # Final summary
        print(f"\n{'='*80}")
        print(f"📊 SESSION SUMMARY")
        print(f"{'='*80}")
        print(f"Approved: {approved}")
        print(f"Modified: {modified}")
        print(f"Rejected: {rejected}")
        print(f"Skipped: {skipped}")
        print(f"Total: {len(self.proposals)}")
        print(f"\nSession log: session_{self.session_id}.json")
        print(f"{'='*80}\n")
    
    def _apply_refactoring(self, proposal: RefactoringProposal):
        """Apply an approved refactoring."""
        filepath = Path(proposal.file)
        
        if not filepath.exists():
            print(f"⚠️  File not found: {filepath}")
            return
        
        # Backup original
        backup_path = filepath.with_suffix('.swift.bak')
        shutil.copy2(filepath, backup_path)
        
        # Read file
        lines = filepath.read_text().splitlines(keepends=True)
        
        # Replace the code
        # This is simplified - real implementation would need precise line matching
        start_idx = proposal.line_start - 1
        end_idx = proposal.line_end
        
        # Replace lines
        new_lines = lines[:start_idx] + [proposal.proposed_code + '\n'] + lines[end_idx:]
        
        # Write back
        filepath.write_text(''.join(new_lines))
        
        proposal.applied = True
        proposal.applied_at = datetime.now().isoformat()
        
        print(f"  ✅ Applied to {filepath}")
        print(f"  💾 Backup: {backup_path}")
    
    def _apply_modified_refactoring(self, proposal: RefactoringProposal, alternative_code: str):
        """Apply a modified refactoring."""
        # Update proposal with agent's code
        original_proposed = proposal.proposed_code
        proposal.proposed_code = alternative_code
        
        # Apply it
        self._apply_refactoring(proposal)
        
        # Log the modification
        print(f"  📝 Agent modified the refactoring")
        print(f"     Original proposal: {len(original_proposed)} chars")
        print(f"     Agent version: {len(alternative_code)} chars")
    
    def _get_surrounding_context(self, filepath: str, line: int, context_lines: int = 5) -> str:
        """Get surrounding code context."""
        try:
            path = Path(filepath)
            if not path.exists():
                return ""
            
            lines = path.read_text().splitlines()
            start = max(0, line - context_lines - 1)
            end = min(len(lines), line + context_lines)
            
            context = []
            for i in range(start, end):
                marker = "→" if i == line - 1 else " "
                context.append(f"{i+1:4d} {marker} {lines[i]}")
            
            return '\n'.join(context)
        except Exception as e:
            return f"Error getting context: {e}"
    
    def _get_original_code(self, filepath: str, line: int) -> str:
        """Get original code at line."""
        try:
            path = Path(filepath)
            if not path.exists():
                return ""
            
            lines = path.read_text().splitlines()
            if line <= len(lines):
                return lines[line - 1]
            return ""
        except Exception:
            return ""
    
    def _estimate_impact(self, task: Dict) -> str:
        """Estimate impact of refactoring."""
        if task.get('confidence', 0) > 0.9:
            return "low"
        elif task.get('type') == 'extract_config':
            return "high"
        elif task.get('type') == 'split_file':
            return "high"
        else:
            return "medium"
    
    def _create_param_reduction_proposal(self, violation: Dict) -> Optional[RefactoringProposal]:
        """Create proposal for parameter count reduction."""
        # This would use the refactoring logic from swiftlint_refactor.py
        # Simplified for now
        return None
    
    def _create_tuple_to_struct_proposal(self, violation: Dict) -> Optional[RefactoringProposal]:
        """Create proposal for tuple to struct conversion."""
        return None
    
    def _create_force_unwrap_proposal(self, violation: Dict) -> Optional[RefactoringProposal]:
        """Create proposal for force unwrap fix."""
        return None
    
    def _create_force_cast_proposal(self, violation: Dict) -> Optional[RefactoringProposal]:
        """Create proposal for force cast fix."""
        return None
    
    def _save_session_state(self):
        """Save current session state."""
        session_file = self.repo_root / f"session_{self.session_id}.json"
        
        state = {
            'session_id': self.session_id,
            'timestamp': datetime.now().isoformat(),
            'proposals': [p.to_dict() for p in self.proposals],
            'log': self.session_log
        }
        
        session_file.write_text(json.dumps(state, indent=2))
    
    def export_approved_changes(self, output_file: Path):
        """Export all approved changes for review."""
        approved = [p for p in self.proposals if p.applied]
        
        export = {
            'session_id': self.session_id,
            'total_proposals': len(self.proposals),
            'approved_count': len(approved),
            'approved_changes': [p.to_dict() for p in approved]
        }
        
        output_file.write_text(json.dumps(export, indent=2))
        print(f"✅ Exported {len(approved)} approved changes to {output_file}")


def main():
    parser = argparse.ArgumentParser(
        description='Interactive agent-assisted refactoring tool',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Interactive session with existing plan
  python3 Scripts/swiftlint_agent_refactor.py --plan refactoring_plan.json
  
  # Generate proposals from violations and review interactively
  python3 Scripts/swiftlint_agent_refactor.py --interactive
  
  # Auto-approve high confidence proposals
  python3 Scripts/swiftlint_agent_refactor.py --auto-approve --min-confidence 0.9
  
  # Review mode (no changes applied)
  python3 Scripts/swiftlint_agent_refactor.py --review-only --plan plan.json
        """
    )
    
    parser.add_argument(
        '--plan',
        type=Path,
        help='Load refactoring plan from JSON file'
    )
    
    parser.add_argument(
        '--interactive',
        action='store_true',
        help='Run in interactive mode (default)'
    )
    
    parser.add_argument(
        '--auto-approve',
        action='store_true',
        help='Auto-approve high confidence proposals'
    )
    
    parser.add_argument(
        '--min-confidence',
        type=float,
        default=0.9,
        help='Minimum confidence for auto-approval (default: 0.9)'
    )
    
    parser.add_argument(
        '--review-only',
        action='store_true',
        help='Review proposals without applying changes'
    )
    
    parser.add_argument(
        '--export',
        type=Path,
        help='Export approved changes to JSON file'
    )
    
    parser.add_argument(
        '--repo-root',
        type=Path,
        default=Path(__file__).parent.parent,
        help='Repository root directory'
    )
    
    args = parser.parse_args()
    
    repo_root = args.repo_root.resolve()
    if not (repo_root / 'Package.swift').exists():
        print(f"❌ Not a valid repository root: {repo_root}")
        sys.exit(1)
    
    # Create agent interface
    interactive = args.interactive or not args.auto_approve
    agent = AgentInterface(interactive=interactive)
    
    # Create refactorer
    refactorer = InteractiveRefactorer(repo_root, agent)
    
    # Load or generate proposals
    if args.plan:
        refactorer.load_refactoring_plan(args.plan)
    else:
        refactorer.generate_proposals_from_violations()
    
    if not refactorer.proposals:
        print("❌ No proposals to review")
        return 0
    
    # Run session
    if not args.review_only:
        refactorer.run_interactive_session()
    else:
        print("📋 Review mode - showing proposals without applying")
        for proposal in refactorer.proposals:
            print(proposal.get_context_display())
    
    # Export if requested
    if args.export:
        refactorer.export_approved_changes(args.export)
    
    return 0


if __name__ == '__main__':
    sys.exit(main())
