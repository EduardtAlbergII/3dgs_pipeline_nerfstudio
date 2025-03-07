# Getting started
Just adjust the environment variables in the settings.env and put your data in the data folder with the following structure: 
- data
- - dataset_name
- - - images
e.g.
- data
- - truck
- - - images

You can also provide a video instead of a set of images in the images folder. But in this case you have to remove the images folder, otherwise the image extract process will be skipped.

You can start the process with the `docker compose up` command. The whole process is:

1. [if video] extract images from the video
2. [if video] preprocess the images with https://github.com/SharkWipf/nerf_dataset_preprocessing_helper.git
3. SfM with Colmap/Glomap
4. Convert to nerfstudio format
5. Train the Splat

Every Step creates a folder in the dataset folder and if something fails, you can delete the last folder and restart the process and it will continue with the given data. ONLY the ns-train folder will be removed after a successful training.