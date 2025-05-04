from pwn import *
from checklib import *

context.log_level = 'CRITICAL'

# global const
PORT = 9001
TCP_CONNECTION_TIMEOUT = 5
TCP_OPERATIONS_TIMEOUT = 7

class CheckMachine:
	sock = None

	def __init__( self, checker ):
		self.c = checker
		self.port = PORT

	def connect( self ):
		try:
			self.sock = remote( self.c.host, self.port, timeout = TCP_CONNECTION_TIMEOUT )
		except Exception as e:
			self.sock = None
			return False, Status.DOWN, 'Connection timeout!\nException: {}'.format(e)

		self.sock.settimeout( TCP_OPERATIONS_TIMEOUT )
		return True, None, None

	def disconnect( self ):
		try:
			self.sock.close()
			self.sock = None
		except:
			self.sock = None
