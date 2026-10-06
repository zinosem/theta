import os
import re

def audit():
    findings = []
    
    for root, dirs, files in os.walk('Source'):
        for file in files:
            if not file.endswith(('.m', '.mm', '.h')):
                continue
            path = os.path.join(root, file)
            with open(path, 'r', encoding='utf-8', errors='ignore') as f:
                lines = f.readlines()
            
            for i, line in enumerate(lines):
                line_num = i + 1
                
                # Check for deprecated keyWindow
                if '[UIApplication sharedApplication].keyWindow' in line or 'app.keyWindow' in line or 'sharedApplication.keyWindow' in line:
                    findings.append((path, line_num, 'Deprecated .keyWindow (can be nil on iOS 15/16/17/18, causing layout/dialog failures)'))
                
                # Check for hardcoded screen dimensions or bounds
                if '[UIScreen mainScreen].bounds' in line:
                    findings.append((path, line_num, 'Deprecated [UIScreen mainScreen].bounds in iOS 16+'))
                
                # Check for KVC without try block
                if 'valueForKey:' in line and '@try' not in ''.join(lines[max(0, i-4):i]):
                    if 'ThetaValueForKey' not in line:
                        findings.append((path, line_num, 'Direct valueForKey: outside @try block (risk of NSUnknownKeyException crash)'))
                
                # Check for retain cycle in UIAction
                if 'actionWithHandler:' in line:
                    surrounding = ''.join(lines[max(0, i-3):min(len(lines), i+20)])
                    if 'weakSelf' in surrounding and 'self ' in surrounding and 'strongSelf' not in surrounding:
                        findings.append((path, line_num, 'Retain cycle risk: self used inside UIAction block where weakSelf was declared'))
                
                # Check for performSelector without respondsToSelector
                if 'performSelector:' in line and 'respondsToSelector' not in ''.join(lines[max(0, i-3):i]):
                    if not line.strip().startswith('//'):
                        findings.append((path, line_num, 'performSelector: called without respondsToSelector: guard'))
                
                # Check for file path hardcoding
                if '/var/mobile/' in line and 'NSTemporaryDirectory' not in line:
                    findings.append((path, line_num, 'Hardcoded /var/mobile path (can fail on jailed sideload container sandboxes)'))

    # Group by category
    print(f"Total findings: {len(findings)}")
    from collections import defaultdict
    by_cat = defaultdict(list)
    for p, l, msg in findings:
        by_cat[msg].append((p, l))
        
    for cat, items in by_cat.items():
        print(f"\n--- {cat} ({len(items)} occurrences) ---")
        for p, l in items[:8]:
            print(f"  {p}:{l}")
        if len(items) > 8:
            print(f"  ... and {len(items)-8} more")

if __name__ == '__main__':
    audit()
