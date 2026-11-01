"""Positive contracts for the reviewed native process boundary; never execute QML."""
import ast
import re


def array_parts(text):
    depth=0;quote='';escaped=False;start=1;parts=[]
    for i,c in enumerate(text):
        if quote:
            if escaped:escaped=False
            elif c=='\\':escaped=True
            elif c==quote:quote=''
            continue
        if c in '\"\'':quote=c
        elif c=='[':depth+=1
        elif c==']':
            depth-=1
            if depth==0:
                parts.append(text[start:i].strip());return parts
        elif c==',' and depth==1:parts.append(text[start:i].strip());start=i+1
    raise AssertionError('Unclosed command array')


def validate_qml_commands(text,http=False):
    count=0
    for match in re.finditer(r'(?:Quickshell\.execDetached\s*\(|\bcommand\s*[:=])\s*',text):
        value=text[match.end():];count+=1
        if http and re.match(r'current\.spec\.argv\s*(?:\n|;|$)',value):continue
        assert value.startswith('['),'A process command must have a reviewed literal shape'
        parts=array_parts(value)
        try:program=ast.literal_eval(parts[0])
        except (ValueError,SyntaxError):raise AssertionError('Process executable must be literal')
        if program=='notify-send':assert len(parts)==5 and parts[1]=='"-a"'
        elif program=='/bin/bash':
            assert len(parts)>=3 and parts[1] in {'helper','root.helper'}
            assert parts[2] in {'"init"','"p2pool"','"wallet"','"remove"','action'}
        else:raise AssertionError('Process executable is outside the reviewed allowlist')
    return count


def validate_helper_actions(text):
    actions=set(re.findall(r'^([a-z*][a-z0-9*-]*)\)',text,re.M))
    assert actions=={'init','p2pool','wallet','register-uri','remove','*'},'Native action set changed; review required'
