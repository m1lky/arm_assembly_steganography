# Arm Assembly Caesar Cipher and Steganography

I created this for an assignment in one of my special topics electives while working on my Bachelor's in CS. 

This project will request an image file in the .pgm format, and a text file to encrypt and encode. 

Using the LSB of each pixel from the image, the length of the message, the Caesar cipher key, and the message itself are encoded into the image, and produce an image that should look functionally identical.

main.s decrypts the image's message.

# How to run

On an arm chipset (I used a raspberry pi model 3), run 
```
as -o main.o [main or p3encrypt].s
gcc -o main main.o
./main
```

Christmas.txt and obama.pgm are included as test files. The text file cannot be larger than 1/4 the size of the image, due to the method of encoding.