-- main.lua (your project entry point)
package.path = "./?.lua;./?/init.lua;" .. package.path

-- run test on router
dofile("tests/basic.test.lua")
