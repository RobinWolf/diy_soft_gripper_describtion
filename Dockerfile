##############################################################################
##                           1. stage: Base Image                           ##
##############################################################################
ARG ROS_DISTRO=humble
FROM osrf/ros:$ROS_DISTRO-desktop as base

# Configure DDS
COPY dds_profile.xml /opt/misc/dds_profile.xml
ENV FASTRTPS_DEFAULT_PROFILES_FILE=/opt/misc/dds_profile.xml

# Create user (for deployment container without root privileges)
ARG USER=hephaestus
ARG PASSWORD=automaton
ARG UID=1000
ARG GID=1000
ENV USER=$USER
RUN groupadd -g $GID $USER \
    && useradd -m -u $UID -g $GID --shell $(which bash) $USER   

#install xacro package (additional necessarity when not using the ur-package from ros)
USER root
RUN apt-get update && apt-get install -y ros-humble-xacro
USER ${USER}

# Setup workpace
USER $USER
RUN mkdir -p /home/$USER/ros2_ws/src
WORKDIR /home/$USER/ros2_ws

##############################################################################
##       2. stage: clone the gripper-description repo from github           ##
##############################################################################
FROM base as diy-gripper

# Install git to clone diy-soft-gripper-description packages
USER root
RUN apt-get update && apt-get install --no-install-recommends -y git
USER $USER

# Clone the diy-soft-gripper-description package into its own workspace
RUN mkdir -p /home/$USER/dependencies/diy_soft_gripper_description_ws/src
RUN cd /home/$USER/dependencies/diy_soft_gripper_description_ws/src && \
    git clone https://github.com/RobinWolf/diy_soft_gripper_description.git

# Build the diy-gripper package
RUN cd /home/$USER/dependencies/diy_soft_gripper_description_ws && \
    . /opt/ros/$ROS_DISTRO/setup.sh && \
    colcon build

# Add built diy-gripper package to entrypoint
USER root
RUN sed -i 's|exec "\$@"|source "/home/'"${USER}"'/dependencies/diy_soft_gripper_description_ws/install/setup.bash"\n&|' /ros_entrypoint.sh
USER $USER

##############################################################################
##               3. stage: gripper visualisation (deployment)               ##
##############################################################################


# Add a default command to start visualization of the gripper by default whrn buildung the container
CMD ["ros2", "launch", "diy_soft_gripper_description", "visualize.launch.py"]
