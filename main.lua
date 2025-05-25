-- main.lua (your project entry point)
package.path = "./?.lua;./?/init.lua;" .. package.path

dofile("tests/basic.test.lua")
