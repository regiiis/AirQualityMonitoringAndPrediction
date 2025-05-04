# memory_manager.py
import gc


class MemoryManager:
    @staticmethod
    def cleanup():
        gc.collect()
        import time

        time.sleep(0.1)

    @staticmethod
    def show_memory_info():
        print(f"Free memory: {gc.mem_free()} bytes")
        print(f"Allocated memory: {gc.mem_alloc()} bytes")
