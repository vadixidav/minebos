all:	header.asm main.asm footer.asm
	./acme -o disk_1cb11b67303e6eba.img --cpu 65el02 main.asm

clean:
	rm disk_1cb11b67303e6eba.img
