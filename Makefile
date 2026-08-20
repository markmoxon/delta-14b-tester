BEEBASM?=beebasm
PYTHON?=python

.PHONY:all
all:
	$(BEEBASM) -i deltest.asm -v -do deltest.ssd -boot DELTEST > compile.txt

.PHONY:b2
b2:
	curl -G "http://localhost:48075/reset/b2"
	curl -H "Content-Type:application/binary" --upload-file "deltest.ssd" "http://localhost:48075/run/b2?name=deltest.ssd"
