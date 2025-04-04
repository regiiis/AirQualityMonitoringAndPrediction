# Mock implementation of the abc module for MicroPython. Real abc module used in the CI/CD pipeline.


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
