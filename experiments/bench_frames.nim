
import os

discard execShellCmd("nim c -r -d:release -d:cpu -d:benchy run_frames.nim" )
