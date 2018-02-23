# MNIST

The MNIST hand-written number recognition database has been around for quite some time and is the "Hello, world" analog for computer vision programming.  Deep learning algorithms have achieved near perfect prediction results with this dataset, so the purpose of this project is not to improve on what's already been done over and over again.  This is a fun exercise in feature extraction; instead of using 784 pixels as input into a given machine learning algorithm, I wanted to extra as many "physical" properties from each image as I could to see what kind of accuracy could be achieved with considerably fewer input variables.  It was an interesting endeavour to think about how our minds actually work to distinguish between one digit and another.  For example, a very narrow image would likely be a 1 or an image with two distinct "holes" is probably an 8.  How does one extract that type of information from an image?

Data can be found here:  https://www.kaggle.com/c/digit-recognizer/data

Note that the trainset_s and testset_s csv files in this repository and loaded in the code are actually sample sets that contain only 10% of the original data.  That should make it easier for anyone who wants to replicate the results to do so in a reasonable amount of time.  Otherwise, rendering the data/models would take hours.
