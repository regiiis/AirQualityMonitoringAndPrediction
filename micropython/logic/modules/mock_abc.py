# Simple abc module for MicroPython


def abstractmethod(func):
    """
    A decorator indicating abstract methods.

    In MicroPython, this is just a marker and doesn't enforce implementation.
    """
    return func


class ABC:
    """
    Helper class that provides a standard way to create an ABC.

    In MicroPython, this is just a marker and doesn't enforce implementation.
    """

    pass
