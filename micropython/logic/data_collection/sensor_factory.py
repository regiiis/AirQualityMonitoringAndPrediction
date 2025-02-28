"""
Sensor Factory for creating sensor instances
"""


class SensorFactory:
    """
    Simple factory class that creates sensor instances
    """

    # Dictionary to store sensor types and their classes
    _sensors = {}

    @classmethod
    def register(cls, sensor_type, sensor_class):
        """
        Register a sensor type with the factory
        """
        cls._sensors[sensor_type.lower()] = sensor_class

    @classmethod
    def create(cls, sensor_type, **kwargs):
        """
        Create a sensor by type

        Args:
            sensor_type: The type of sensor to create
            **kwargs: Parameters to pass to the sensor constructor

        Returns:
            A sensor instance
        """
        sensor_type = sensor_type.lower()
        if sensor_type not in cls._sensors:
            raise ValueError(f"Unknown sensor type: {sensor_type}")

        # Get the sensor class and instantiate it
        sensor_class = cls._sensors[sensor_type]
        return sensor_class(**kwargs)


# Register known sensors
try:
    from adapter.ina219 import INA219Adapter

    SensorFactory.register("ina219", INA219Adapter)
except ImportError:
    pass

try:
    from adapter.hyt221 import HYT221Adapter

    SensorFactory.register("hyt221", HYT221Adapter)
except ImportError:
    pass
