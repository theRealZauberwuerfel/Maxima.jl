const inputchannel = Channel{String}(1)
const outputchannel = Channel{String}(1)

"""
    connect(port)

Starting at port `port`, try to start a TCP server. If this fails try the next
port until successful.

Note: If your starting port unreasonable (like 20) this will
hang because it opens too many files in the search for an open port.
"""
function connect(port)
    try
        server = listen(port)
        return server, port
    catch err
        connect(port + 1)
    end
end

"""
    input(str::String)

Pass a string to the maxima client. If the string is not a valid maxima
expression this may hang.
"""
function input(str::String)
    put!(inputchannel, str)
    return nothing
end


"""
    output()

Take raw output from the maxima client.
"""
function output()
    take!(outputchannel)
end

"""
    startserver(port)

Start up a maxima client-server pair trying port `port` first.
"""
function startserver(port)
    server, port = connect(port)
    socketrequest = @spawn accept(server)
    clientrequest = @spawn run(`
        maxima --server=$port --very-quiet
		--run-string="display2d: false\$"`)
    socket = fetch(socketrequest)

    readavailable(socket)
    stopchar = Char(4)

    while true
        input = take!(inputchannel)
        write(socket, input)
		char = read(socket, Char)
		write(socket, "print(ascii(4))\$")
		str = string(char)
		while char != stopchar
			char = read(socket, Char)
			str = string(str, char)
		end
	    str = rstrip(str, stopchar)
        put!(outputchannel, str)
    end
    return nothing
end

"""
    killserver()

Kill maxima client with `quit();` call from the server
"""
function killserver()
    input("quit();")
    return nothing
end

# ---------------------------------------------
#   Start up the default server-client pair by
#   (1) choosing a default port,
#   (2) spawning the client-server pair and,
#   (3) registering `killserver` to run on exit

const defaultport = 8080
@spawn startserver(defaultport)
atexit(killserver)   
