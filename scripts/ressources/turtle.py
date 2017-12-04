import time
from turtle import * 

with open("turtle") as f:
    content = f.readlines()

content = [x.replace('degrees', '').replace('spaces', '').replace('de', '').strip() for x in content]
for phrase in content:
    if phrase is not '':
        val = ''.join(list(filter(str.isdigit, phrase)))
        print(val)
        val = int(val)
        if 'Avance' in phrase:
            forward(val)
        elif 'Recule' in phrase:
            backward(val)
        elif 'gauche' in phrase:
            left(val)
        elif 'droite' in phrase:
            right(val)            

time.sleep(5000)
