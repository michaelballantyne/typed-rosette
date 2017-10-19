artifact: Symbolic Types for Lenient Symbolic Execution
===

This is the source code for the artifact that accompanies "Symbolic Types for Lenient Symbolic Execution".

To build the artifact:
- Install [packer](https://www.packer.io), [Racket](https://racket-lang.org),
  and [VirtualBox](https://www.virtualbox.org/wiki/Downloads).
- Run `make`. You should have a new folder `./output-virtualbox-iso/` that
  contains a `.ovf` and `.vmdk` file. Building the image takes approximately 1 hour.
- Open VirtualBox, click `File -> Import Appliance`, then navigate to the
  `.ovf` file.
- We recommend creating the VM with 2GB of RAM.

Inside the VM, the Desktop folder will have a copy of the POPL 2018 paper, a
shortcut to the DrRacket IDE, and a `README.html` with detailed instructions.

VM username: `artifact`

VM password: `artifact`
