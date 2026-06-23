
# 4-Axis Robotic Arm with Inverse Kinematics


A 4-axis robotic arm system controlled by an STM32 microcontroller using bare-metal C, inverse/forward kinematics, linear interpolation, UART-based G-code communication, and TIM2-based PWM servo control.

The project includes a MATLAB-based host interface for user input, G-code command generation, UART communication, and digital twin visualization. The main kinematics and actuator control logic run on the STM32 microcontroller.

This project demonstrates an end-to-end embedded robotics workflow: mechanical design, mathematical modeling, real-time microcontroller-based motion control, serial communication, PWM actuator control, and physical system testing.


Project Overview

The aim of this project is to design and implement a 4-axis robotic arm capable of moving its end-effector to desired spatial coordinates. The system receives target commands from a MATLAB GUI, converts them into standardized G-code commands, transmits them to the STM32 microcontroller over UART, and then calculates the required joint motions using inverse kinematics.

The STM32 controls four servo motors through PWM signals generated directly from timer peripherals. The software was developed with a bare-metal C approach to achieve deterministic timing, low memory usage, and direct hardware control.

Key Features
4-axis robotic arm control
STM32-based embedded control system
Bare-metal C programming
Forward Kinematics and Inverse Kinematics implementation
Linear interpolation for smooth point-to-point motion
UART communication between MATLAB GUI and STM32
Custom G-code parser
Interrupt-driven serial reception
TIM2-based 4-channel PWM servo control
MATLAB GUI for real-time user input
Digital twin visualization for motion verification
3D-printed mechanical structure
Servo horn reinforcement for improved torque transmission
Sim-to-real error analysis
Proposed calibration strategy for future improvements


## System Architecture

The system is built around an STM32-based embedded control architecture. The MATLAB side is used as a user interface and command-generation environment, while the real-time motion control logic runs on the STM32 microcontroller.

The overall workflow is:

```text
User Input / GUI
        ↓
G-code Command Generation
        ↓
UART Serial Communication
        ↓
STM32 G-code Parser
        ↓
Inverse Kinematics + Linear Interpolation
        ↓
PWM Pulse Width Calculation
        ↓
Servo Motor Actuation
```

### Host-Side User Interface

The host-side interface is implemented in MATLAB. Its main role is not to perform the low-level robotic control, but to provide a user input environment, generate standardized G-code commands, send these commands to the STM32 over UART, and visualize the planned motion through a digital twin.

Main responsibilities:

* User input handling
* Keyboard and mouse event handling
* Cartesian coordinate command generation
* G-code command formatting
* UART serial communication with STM32
* Digital twin visualization
* Waiting for acknowledgment from STM32 before sending the next command

### STM32 Embedded Control Layer

The STM32 microcontroller is responsible for the actual embedded control process. It receives G-code commands over UART, parses them, calculates the required joint angles, applies linear interpolation for smoother motion, converts the resulting angles into PWM pulse widths, and drives the servo motors.

Main responsibilities:

* UART RX interrupt handling
* Command buffering
* G-code parsing
* Forward / Inverse Kinematics processing
* Linear interpolation for smooth motion

* ## MATLAB Host Interface

The MATLAB environment is used as a host-side interface for user interaction and command transmission. It allows the user to control the robotic arm through keyboard and mouse inputs, converts these inputs into standardized G-code strings, and sends them to the STM32 microcontroller using UART serial communication.

The MATLAB side also includes a digital twin visualization that plots the expected forward-kinematics-based motion of the robotic arm. This makes it possible to compare the planned mathematical trajectory with the real physical motion of the manipulator.

Main functions:

* Capturing user input
* Generating Cartesian target commands
* Formatting commands as G-code
* Sending commands through UART
* Waiting for STM32 acknowledgment before sending the next command
* Visualizing the planned motion through a digital twin

The real-time embedded control, inverse kinematics calculation, interpolation, PWM pulse width calculation, and servo actuation are handled by the STM32 firmware.

* PWM pulse width calculation
* TIM2-based 4-channel PWM generation
* Servo motor actuation
* Maintaining the current actuator position while waiting for new commands
