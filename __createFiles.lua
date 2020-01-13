file.remove("msgList.txt");
file.open("msgList.txt", "w+")
for i = 1, 3 do
    file.writeline('1')
end
for i = 4, 14 do
    file.writeline('0')
end
for i = 15, 32 do
    file.writeline('1')
end
file.close()

file.remove("log.txt");
file.open("log.txt", "w+")
for i = 1, 4 do
    file.writeline('0')
end
file.close()

