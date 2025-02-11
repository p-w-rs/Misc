from pynput import keyboard, mouse
import time
import threading

class AutoClicker:
    def __init__(self, cps=1):
        self.clicking = False
        self.running = True
        self.cps = cps  # clicks per second
        print("AutoClicker initialized")

        # Create mouse controller
        self.mouse = mouse.Controller()
        print("Mouse controller created")

        # Start the keyboard listener
        print("Starting keyboard listener...")
        self.keyboard_listener = keyboard.Listener(on_press=self.on_press)
        self.keyboard_listener.start()
        print("Keyboard listener started")

        # Start clicking thread
        self.click_thread = threading.Thread(target=self.auto_click, daemon=True)
        self.click_thread.start()
        print("Click thread started")

    def on_press(self, key):
        try:
            # For regular character keys, we need to check the char value
            if hasattr(key, 'char'):
                if key.char == 'g':  # 'g' key to start
                    self.clicking = True
                    print('Auto clicking: On')
                elif key.char == 'r':  # 'r' key to stop
                    self.clicking = False
                    print('Auto clicking: Off')
                elif key.char == 'q':  # 'q' key to quit
                    print("Exiting program...")
                    self.clicking = False
                    self.running = False
                    return False
        except AttributeError as e:
            print(f"Error: {e}")

    def auto_click(self):
        while self.running:
            if self.clicking:
                self.mouse.click(mouse.Button.left)
                print("Click!")  # Debug print
                time.sleep(0.001)

if __name__ == "__main__":
    print("Starting program...")
    print("Press 'g' to start clicking")
    print("Press 'r' to stop clicking")
    print("Press 'q' to quit")
    clicker = AutoClicker(cps=1)

    try:
        while clicker.running:
            time.sleep(0.1)
    except KeyboardInterrupt:
        print("\nProgram terminated by user")
        clicker.running = False
