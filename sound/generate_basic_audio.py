#!/usr/bin/python3
#
# Author: Adam Rogoyski (adam@rogoyski.com).
# Public domain software.
#
# Generate a basic raw audio file for the text-based versions to use.

import itertools
import math
import sys

# Generate the range of note frequencies from C1 to C5.
note_symbols = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']
frequencies = [1440*2**(i/12) for i in range(49)]

# Cycle the note symbols with the frequencies.
notes_ = tuple(zip(itertools.cycle(note_symbols), frequencies))

# Map the octave numbers 1-5 to the notes to get a sequence from (C1, C#1, ... A#4, B4, C5).
notes = []
for i, (symbol, frequency) in enumerate(notes_):
  notes.append(('{}{}'.format(symbol, 1 + int(i / 12)), frequency))
N = dict(notes)

# Have a null note for silence.
N[""] = 0

# The mainline and counterpoint to Korobeiniki. Meant to be played in a loop.
line1 = tuple(itertools.chain.from_iterable([('E2',)*4, ('B1',)*2, ('C2',)*2, ('D2',)*2, ('E2',), ('D2',), ('C2',)*2, ('B1',)*2, ('A1',)*3, ('',)*1, ('A1',)*2, ('C2',)*2, ('E2',)*4, ('D2',)*2, ('C2',)*2, ('B1',)*5, ('',)*1, ('C2',)*2, ('D2',)*4, ('E2',)*4, ('C2',)*4, ('A1',)*3, ('',)*1, ('A1',)*8, ('',)*2, ('D2',)*4, ('F2',)*2, ('A2',)*4, ('G2',)*2, ('F2',)*2, ('E2',)*6, ('C2',)*2, ('E2',)*4, ('D2',)*2, ('C2',)*2, ('B1',)*6, ('C2',)*2, ('D2',)*4, ('E2',)*4, ('C2',)*4, ('A1',)*3, ('',)*1, ('A1',)*8, ('E2',)*8, ('C2',)*8, ('D2',)*8, ('B1',)*8, ('C2',)*8, ('A1',)*8, ('G#1',)*8, ('B1',)*8, ('E2',)*8, ('C2',)*8, ('D2',)*8, ('B1',)*8, ('C2',)*4, ('E2',)*4, ('A2',)*8, ('G#2',)*16]))
line2 = tuple(itertools.chain.from_iterable([('B1',)*4, ('G#1',)*2, ('A1',)*2, ('B1',)*4, ('A1',)*2, ('G#1',)*2, ('E1',)*4, ('E1',)*2, ('A1',)*2, ('C2',)*4, ('B1',)*2, ('A1',)*2, ('G#1',)*4, ('',)*2, ('E1',)*2, ('G#1',)*4, ('B1',)*2, ('C2',)*2, ('A1',)*4, ('E1',)*3, ('',)*1, ('E1',)*8, ('',)*2, ('F1',)*4, ('A1',)*2, ('C2',)*4, ('B1',)*2, ('A1',)*2, ('G1',)*6, ('E1',)*2, ('G1',)*2, ('A1',)*1, ('G1',)*1, ('F1',)*2, ('E1',)*2, ('G#1',)*2, ('E1',)*2, ('G#1',)*2, ('E1',)*2, ('B1',)*4, ('C2',)*2, ('B1',)*2, ('A1',)*4, ('E1',)*12, ('C2',)*8, ('A1',)*8, ('B1',)*8, ('G#1',)*8, ('A1',)*8, ('E1',)*8, ('E1',)*8, ('G#1',)*8, ('C2',)*8, ('A1',)*8, ('B1',)*8, ('G#1',)*8, ('A1',)*4, ('C2',)*4, ('E2',)*8, ('E2',)*16]))
assert(len(line1) == len(line2))

line1_balance, line2_balance = (0.5, 0.5)
assert (sum((line1_balance, line2_balance)) == 1)

frequency = 44100
quarter_note_samples = 1000
songdata = []
for i in range(quarter_note_samples * len(line1)):
  j = int(i / quarter_note_samples)
  songdata.append(min(255, max(0, int(127 + line1_balance*127*(math.sin(2*math.pi/frequency*i*N[line1[j]])) +
                                            line2_balance*127*(math.sin(2*math.pi/frequency*i*N[line2[j]]))))))
sys.stdout.buffer.write(bytes(songdata))
