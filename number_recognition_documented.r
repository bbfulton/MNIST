## Draw function
## as.data.frame(t(matrix(data = as.numeric(trainset[2,2:785]), nrow = 28, ncol = 28)))

# The MNIST dataset has been around for a number of years and acts as an introductory exercise in 
# computer vision models.  There's not much room for improvement in accuracy over existing deep 
# learning methodologies, and most current computer vision tasks are far more complex with further
# reaching applications than simple number recognition does.  With that in mind, the purpose of 
# this particular exercise is not to create the most accurate or efficient model for numerical 
# recognition; rather, this is an exercise in feature engineering, where the functions distill 
# each image of 784 pixels into just a handful of numerical features that represent different aspects of
# matrix representation of the image to compare the accuracy of models based on those calculations
# compares to existing models that are defined by the entire images.

# Initializing the packages required 

require(tidyverse)
require(nnet)
require(caret)
require(randomForest)
require(EBImage)
require(keras)

# Reading in the training data and the test data

# trainset <- read.csv("C:\\Users\\Bryan\\Google Drive\\Kaggle\\numbers\\numberrecognition.csv",
#                      stringsAsFactors = FALSE)
# testset <- read.csv("C:\\Users\\Bryan\\Google Drive\\Kaggle\\numbers\\test.csv",
#                     stringsAsFactors = FALSE)

trainset <- read.csv("C:\\Users\\Bryan\\Google Drive\\Kaggle\\numbers\\trainset_s.csv", 
                     stringsAsFactors = FALSE)
testset <- read.csv("C:\\Users\\Bryan\\Google Drive\\Kaggle\\numbers\\testset_s.csv",
                    stringsAsFactors = FALSE)
trainset <- trainset[,-1]
testset <- testset[,-1]

# Splitting the training data into two tables:  The pixel values for each image and the number 
# that the image represents

train.x <- trainset[,2:785]
train.y <- trainset[,1]
rm(trainset)

# The training data contains approximately 42,000 images (or 4,200 images for each digit).  
# While this does seem like a sufficient number of entries to create a model for a mere 10 
# classifications (the digits 0-9), there are number of factors (such as size, writing angle, 
# and general differences in handwriting styles) that can lead to a vast number of subtle 
# differences between written versions of the same number.  While more robust models involving
# deep learning methods such as convoluted neural networks are well suited to generalizing these 
# subtle differences, the challenge of this exercise is to programmatically extract information 
# rather than to use established deep learning techniques to solve the problem in the same way
# many others have done before.  The function below takes an image as input, converts the pixels 
# values to square matrix form, rotates the matrix by a random angle measure between -20 and 20 
# degrees, resizes the image by a random amount from 72% to 128% and then converts that matrix 
#back into a conventional dataset entry.  This is an exercise in feature engineering.

# Start with a blank image.  

blank.image <- as.Image(matrix(data = 0, nrow = 28, ncol = 28))

# Function that rotates and scales each image in the dataset.  Starting with a blank image, 
# filling in pixel data into the corresponding null matrix, then rotating it.

rotation <- function(rownum) {
      next.image <- blank.image
      im <- matrix(data = as.numeric(train.x[rownum, 1:784]), nrow = 28, ncol = 28)
      imageData(next.image) <- im
      rotation.angle <- runif(1, -20, 15)
      image.rotate <- rotate(next.image, angle = rotation.angle, output.dim = c(28, 28))
      image.rotate <- image.rotate[1:nrow(image.rotate), 1:ncol(image.rotate)]
      resize.amount <- 2*(round(runif(1, 10, 17), 0))
      image.resize <- resize(image.rotate, resize.amount)
      extra.pixels <- max((resize.amount^2 - 784)/2, 0)
      if (extra.pixels > 0) {
                  image.resize <- image.resize[-c(1:extra.pixels)]
                  s <- 785
                  l <- length(image.resize)
                  image.resize <- image.resize[-c(s:l)]
      }
      next.row <- as.data.frame(
            matrix(data = round(imageData(image.rotate), 6), nrow = 1, ncol = 784, byrow = TRUE))
      return(next.row)
}

# Creating a temporary dataframe to collect the new, rotated image data

temp.df <- as.data.frame(matrix(data = 0, 
                                nrow = nrow(train.x),                            
                                ncol = ncol(train.x)))

# Looping thru the image rotation function and adding each rotated image to the temporary 
# dataframe

for (i in 1:nrow(train.x)) {
      temp.df[i,] <- rotation(i)
}

temp.df <- as.data.frame(t(sapply(1:nrow(train.x), function(x) unlist(rotation(x)))))

# Combining the labels from the original dataset with the rotated data

names(temp.df) <- names(train.x)
train.x <- rbind(train.x, temp.df)
rm(temp.df)

train.y <- c(train.y, train.y)

# And combining the rotated data with the original training data for a more complete dataset
# to analyze and model from

trainset <- as.data.frame(cbind(train.y, train.x))
rm(train.x); rm(train.y)
names(trainset)[1] <- "label"
trainset$label <- as.factor(trainset$label)

# What follows is a series of functions that perform a series of aggregations and calculations
# to condense the 784 pixels down to a much smaller number of variables

# The 'inflections' function takes the numerical values of the pixels in each row of the image 
# and determines how many times consecutive pixel values changes from increasing (or no change)
# to decreasing.  This is a discrete analog to identifying inflection points on a continuous 
# function.  The function tallies these number of points up over all 28 rows in the image
# and returns a single count.


inflections <- function(rownum, dataset) {
      counter <- 0 
      m <- t(matrix(data = as.numeric(dataset[rownum,2:785]), nrow = 28, ncol = 28))
      r <- which(rowSums(m) == 0)
      m <- m[-r,]
      c <- which(colSums(m) == 0)
      m <- m[,-c]
      if (dataset$width[rownum] < 3) {
            counter <- dataset$height[rownum]
      }
      else {
            for (i in 3:ncol(m)) {
                  for (j in 1:nrow(m)) {
                        a <- m[j,i] - m[j,i-1] 
                        b <- m[j,i-1] - m[j,i-2]
                        if (as.numeric(a) * as.numeric(b) < 0) {
                              counter <- counter + 1
                        }
                  }
            }
      }
      return(counter)
}

# The 'height' function simply returns the height (in pixels) of the handwritten digit.  

height <- function(rownum, dataset) {
      m <- t(matrix(data = as.numeric(dataset[rownum,2:785]), nrow = 28, ncol = 28))
      h <- max(which(rowSums(m) > 0)) - min(which(rowSums(m) > 0))
      return(h)
}

# Returns the widths (in pixels) of the handwritten digit.

width <- function(rownum, dataset) {
      m <- t(matrix(data = as.numeric(dataset[rownum,2:785]), nrow = 28, ncol = 28))
      w <- max(which(colSums(m) > 0)) - min(which(colSums(m) > 0))
      return(w)
}

# The 'arcs' function tabulates the number of occurrences where the value of one pixel is 0 and 
# the value of the pixel immediately to its right is not 0.  The concept behind this is to provide
# a metric that distinguishes between one vertical element and two vertical elements.  
# In colloquial mathematical terms, numbers that pass the "horizontal line test" are more likely
# to have low arc-function values than numbers that don't pass the "horizontal line test".  For
# example, 1's are more likely to have lower values than 8's.

arcs <- function(rownum, dataset) {
      counter <- 0
      for (i in 3:785) {
            if (min(as.numeric(dataset[rownum, i]), as.numeric(dataset[rownum, i + 1])) == 0 & max(dataset[rownum, i], dataset[rownum, i + 1]) >= 1) {
                  counter <- counter + 1
            }
      }
      counter <- 0.5 * (counter - 1)
      return(counter)
}

# 'updown' is the ratio of the sum of pixel values in the top half of the number to the sum of
# pixel values in the bottom half of the number

updown <- function(rownum, dataset) {
      m <- t(matrix(data = as.numeric(dataset[rownum,2:785]), nrow = 28, ncol = 28))
      r <- which(rowSums(m) == 0)
      m <- m[-r,]
      c <- which(colSums(m) == 0)
      m <- m[,-c]
      midvert <- 0.5 * dim(m)[1]
      if (ceiling(midvert) - floor(midvert) != 0) {
            midvert <- ceiling(midvert)
            bottom <- sum(rowSums(m[(midvert-1):nrow(m),]))
      } else {
            bottom <- sum(rowSums(m[midvert:nrow(m),]))
      }
      top <- sum(rowSums(m[1:midvert,]))  
      th <- top/bottom
      return(th)
}

# 'leftright' is the ratio of the sum of pixel values in the left half of the number to the sum of
# pixel values in the right half of the number

leftright <- function(rownum, dataset) {
      m <- t(matrix(data = as.numeric(dataset[rownum,2:785]), nrow = 28, ncol = 28))
      r <- which(rowSums(m) == 0)
      m <- m[-r,]
      c <- which(colSums(m) == 0)
      m <- m[,-c]
      if (dataset$width[rownum] < 3) {
            lr <- 1
      }
      else {
            midhor <- 0.5 * dim(m)[2]
            if (ceiling(midhor) - floor(midhor) != 0) {
                  midhor <- ceiling(midhor)
                  right <- sum(colSums(m[,(midhor-1):ncol(m)]))
            } else {
                  right <- sum(colSums(m[,midhor:ncol(m)]))
            }
            print(rownum)
            left <- sum(colSums(m[,1:midhor]))  
            lr <- (left+1)/(right+1)
      }
      return(lr)
}

# The 'upperenclosure' function examines the half of the image and determines how many
# blank pixels (those with value of 0) are at least partially enclosed by non-blank values.
# In this instance, enclosure is defined as having pixels of non-zero value within a certain 
# distance above, below, right, and left of each pixel.  

upperenclosure <- function(rownum, dataset) {
      m <- t(matrix(data = as.numeric(dataset[rownum,2:785]), nrow = 28, ncol = 28))
      counter <- 0
      r <- which(rowSums(m) == 0)
      m <- m[-r,]
      c <- which(colSums(m) == 0)
      m <- m[,-c]
      h <- round(nrow(m)/2)
      for (i in 1:ncol(m)) {
            for (j in 1:h) {
                  right <- 0
                  left <- 0
                  up <- 0
                  down <- 0
                  if (m[j, i] ==  0) {
                        down <- max(m[j:nrow(m), i])
                        up <- max(m[1:j, i])
                        left <- max(m[j, 1:i])
                        right <- max(m[j, i:ncol(m)])
                  }
                  if (right > 0 & left > 0 & up > 0 & down > 0) {
                        counter <- counter + 1
                  }
            }
      }
      return(counter)
}

# 'lowerenclosure' is identical to the 'upperenclosure' function above with the exception that
# it looks at the lower half of each image.

lowerenclosure <- function(rownum, dataset) {
      m <- t(matrix(data = as.numeric(dataset[rownum,2:785]), nrow = 28, ncol = 28))
      counter <- 0
      r <- which(rowSums(m) == 0)
      m <- m[-r,]
      c <- which(colSums(m) == 0)
      m <- m[,-c]
      h <- round(nrow(m)/2)
      for (i in 1:ncol(m)) {
            for (j in h:nrow(m)) {
                  right <- 0
                  left <- 0
                  up <- 0
                  down <- 0
                  if (m[j, i] ==  0) {
                        down <- max(m[j:nrow(m), i])
                        up <- max(m[1:j, i])
                        left <- max(m[j, 1:i])
                        right <- max(m[j, i:ncol(m)])
                  }
                  if (right > 0 & left > 0 & up > 0 & down > 0) {
                        counter <- counter + 1
                  }
            }
      }
      return(counter)
}

# Much like the prior two functions, 'enclosure' counts the total number of enclosed pixels
# in the entire image

enclosure <- function(rownum, dataset) {
      m <- t(matrix(data = as.numeric(dataset[rownum,2:785]), nrow = 28, ncol = 28))
      counter <- 0
      for (i in 1:28) {
            for (j in 1:28) {
                  right <- 0
                  left <- 0
                  up <- 0
                  down <- 0
                  if (m[j, i] ==  0) {
                        down <- max(m[j:28, i])
                        up <- max(m[1:j, i])
                        left <- max(m[j, 1:i])
                        right <- max(m[j, i:28])
                  }
                  if (right > 0 & left > 0 & up > 0 & down > 0) {
                        counter <- counter + 1
                  }
            }
      }
      return(counter)
}

# 'eigval' calculates the eigenvalue of the pixel matrix

eigval <- function(rownum, dataset) {
      m <- t(matrix(data = as.numeric(dataset[rownum,2:785]), nrow = 28, ncol = 28))
      r <- which(rowSums(m) == 0)
      c <- which(colSums(m) == 0)
      u <- intersect(r, c)
      if (length(u) > 0) {
            m <- m[-u,]
            m <- m[,-u]
      }
      ev <- eigen(m)$values
      ev <- as.numeric(sum(ev))
      return(ev)
}

# 'lowerleft' computes the sum of pixel values in the lower left ninth of the matrix.  

lowerleft <- function(rownum, dataset) {
      m <- t(matrix(data = as.numeric(dataset[rownum,2:785]), nrow = 28, ncol = 28))
      r <- which(rowSums(m) == 0)
      m <- m[-r,]
      c <- which(colSums(m) == 0)
      m <- m[,-c]
      s <- sum(m[(nrow(m)-4):nrow(m),1:round(0.5*ncol(m))])
      return(s)
}

# 'upperleft' computes the sum of pixel values in the upper left ninth of the matrix

upperleft <- function(rownum, dataset) {
      m <- t(matrix(data = as.numeric(dataset[rownum,2:785]), nrow = 28, ncol = 28))
      r <- which(rowSums(m) == 0)
      m <- m[-r,]
      c <- which(colSums(m) == 0)
      m <- m[,-c]
      s <- sum(m[1:6,1:round(0.5*ncol(m))])
      return(s)
}

# 'uppercenter' computes the sum of pixel values in the upper center ninth of the matrix

uppercenter <- function(rownum, dataset) {
      m <- t(matrix(data = as.numeric(dataset[rownum,2:785]), nrow = 28, ncol = 28))
      r <- which(rowSums(m) == 0)
      m <- m[-r,]
      c <- which(colSums(m) == 0)
      m <- m[,-c]
      s <- sum(m[1:3,floor(0.25*ncol(m)):round(0.6*ncol(m))])
      return(s)
}

# 'center' computes the sum of pixel values in the center ninth of the matrix

center <- function(rownum, dataset) {
      m <- t(matrix(data = as.numeric(dataset[rownum,2:785]), nrow = 28, ncol = 28))
      r <- which(rowSums(m) == 0)
      m <- m[-r,]
      c <- which(colSums(m) == 0)
      m <- m[,-c]
      s <- sum(m[floor(0.33*nrow(m)):round(0.66*nrow(m)),])
      return(s)
}

# The 'gridsums' function is an analog of the pooling step in a convoluted neural network.  It 
# returns 4 values that indicate the relative location of the high and low pixel densities for 
# each image.

gridsums <- function(rownum, dataset) {
      m <- t(matrix(data = as.numeric(dataset[rownum,2:785]), nrow = 28, ncol = 28))
      r <- which(rowSums(m) == 0)
      m <- m[-r,]
      c <- which(colSums(m) == 0)
      m <- m[,-c]
      if (dataset$width[rownum] < 5) {
            boxsums <- matrix(data = 1000:1029, ncol = 2, nrow = 15)
      } else {
            boxsums <- matrix(data = 0, ncol = ncol(m)-3, nrow = nrow(m)-3)
            for (i in 1:(nrow(m)-3)) {
                  for (j in 1:(ncol(m)-3)) {
                        boxsums[i,j] <- mean(as.numeric(m[i:(i+3), j:(j+3)]))
                  }
            }
      }
      maxrow <- which(rowSums(boxsums) == max(rowSums(boxsums)))
      maxcol <- which(colSums(boxsums) == max(colSums(boxsums)))
      minrow <- which(rowSums(boxsums) == min(rowSums(boxsums)))
      mincol <- which(colSums(boxsums) == min(colSums(boxsums)))
      mm <- list()
      length(mm) <- 4
      mm <- as.list(c(maxrow, maxcol, minrow, mincol))
      return(mm)
}

# Applying the functions outlined above to the training set to create new predictors.

trainset <- trainset %>% mutate(fill = apply(trainset[,2:ncol(trainset)], 1, sum),
                                zeroes = apply(trainset[,2:ncol(trainset)], 1, function(x) length(which(x == 0))))
trainset[,2:785] <- lapply(trainset[,2:785], as.numeric)
trainset <- trainset %>% mutate(width = sapply(1:nrow(trainset), width, dataset = trainset), 
                                height = sapply(1:nrow(trainset), height, dataset = trainset)) 
trainset <- trainset %>% mutate(inflections = sapply(1:nrow(trainset), inflections, dataset = trainset),
                                cent = sapply(1:nrow(trainset), center, dataset = trainset),
                                upcenter = sapply(1:nrow(trainset), uppercenter, dataset = trainset),
                                upleft = sapply(1:nrow(trainset), upperleft, dataset = trainset),
                                lowleft = sapply(1:nrow(trainset), lowerleft, dataset = trainset),
                                eigenval = sapply(1:nrow(trainset), suppressWarnings(eigval), dataset = trainset),
                                enclosurearea = sapply(1:nrow(trainset), enclosure, dataset = trainset))
trainset <- trainset %>% mutate(enclosureratio = trainset$enclosurearea/(trainset$height*trainset$width),
                                upperenclosurearea = sapply(1:nrow(trainset), upperenclosure, dataset = trainset),
                                lowerenclosurearea = sapply(1:nrow(trainset), lowerenclosure, dataset = trainset),
                                leftrightsym = sapply(1:nrow(trainset), leftright, dataset = trainset),
                                arcs = sapply(1:nrow(trainset), arcs, dataset = trainset))
trainset <- trainset %>% mutate(maxconvrow = sapply(1:nrow(trainset), function(x) unlist(gridsums(x, trainset))[1]),
                                maxconvcol = sapply(1:nrow(trainset), function(x) unlist(gridsums(x, trainset))[2]),
                                minconvrow = sapply(1:nrow(trainset), function(x) unlist(gridsums(x, trainset))[3]),
                                minconvcol = sapply(1:nrow(trainset), function(x) unlist(gridsums(x, trainset))[4]))


# Applying the functions outlined above to the testset to create new features.

testset <- testset %>% mutate(fill = apply(testset[,2:ncol(testset)], 1, sum),
                              zeroes = apply(testset[,2:ncol(testset)], 1, function(x) length(which(x == 0))))
testset[,2:785] <- lapply(testset[,2:785], as.numeric)
testset <- testset %>% mutate(width = sapply(1:nrow(testset), width, dataset = testset), 
                              height = sapply(1:nrow(testset), height, dataset = testset)) 
testset <- testset %>% mutate(inflections = sapply(1:nrow(testset), inflections, dataset = testset),
                              cent = sapply(1:nrow(testset), center, dataset = testset),
                              upcenter = sapply(1:nrow(testset), uppercenter, dataset = testset),
                              upleft = sapply(1:nrow(testset), upperleft, dataset = testset),
                              lowleft = sapply(1:nrow(testset), lowerleft, dataset = testset),
                              eigenval = sapply(1:nrow(testset), suppressWarnings(eigval), dataset = testset),
                              enclosurearea = sapply(1:nrow(testset), enclosure, dataset = testset))
testset <- testset %>% mutate(enclosureratio = testset$enclosurearea/(testset$height*testset$width),
                              upperenclosurearea = sapply(1:nrow(testset), upperenclosure, dataset = testset),
                              lowerenclosurearea = sapply(1:nrow(testset), lowerenclosure, dataset = testset),
                              leftrightsym = sapply(1:nrow(testset), leftright, dataset = testset),
                              arcs = sapply(1:nrow(testset), arcs, dataset = testset))
testset <- testset %>% mutate(maxconvrow = sapply(1:nrow(testset), function(x) unlist(gridsums(x, testset))[1]),
                              maxconvcol = sapply(1:nrow(testset), function(x) unlist(gridsums(x, testset))[2]),
                              minconvrow = sapply(1:nrow(testset), function(x) unlist(gridsums(x, testset))[3]),
                              minconvcol = sapply(1:nrow(testset), function(x) unlist(gridsums(x, testset))[4]))

# Scaling the data

feat.names <- c("zeroes", "width", "height", "inflections", "cent", "fill", "upcenter", "upleft", "lowleft", "eigenval",
                "enclosureratio", "upperenclosurearea", "lowerenclosurearea", "leftrightsym", "arcs", "maxconvrow", 
                "maxconvcol", "minconvrow", "minconvcol", "enclosurearea")

trainset[,feat.names] <- sapply(trainset[,feat.names], scale)
testset[,feat.names] <- sapply(testset[,feat.names], scale)

### Saved image

trainset[,grep("pix.*", names(trainset))] <- trainset[,grep("pix.*", names(trainset))]/255
testset[,grep("pix.*", names(testset))] <- testset[,grep("pix.*", names(testset))]/255

# Removing fields that have no variability (all 0s)

co <- which(colSums(trainset[,2:785]) == 0)
co <- co + 1
trainset <- trainset[,-co]
co <- co - 1
testset <- testset[,-co]

# # Removing additional features that are highly correlated
# 
# corr <- cor(trainset[,c(2:740)])
# corr.feats <- findCorrelation(corr, cutoff = 0.95) + 1
# trainset <- trainset[,-corr.feats]
# testset <- testset[,-(corr.feats - 1)]

# To see just how well these new features assist in modeling the data, I'm going to run two different sets of models:
# One with the original data to get a baseline, and one with the engineered features.  

new.train.features <- trainset[,c("label", feat.names)]
original.train <- trainset[,-which(names(trainset) %in% feat.names)]

# Splitting the training set of generated features into a sub-train set and a validation set

set.seed(2718)
intrain <- createDataPartition(new.train.features$label, p = 0.7, list = FALSE)
tr <- new.train.features[intrain,]
va <- new.train.features[-intrain,]

# Creating a simple random forest model for the engineered data

tc <- trainControl(method = "cv", 
                   number = 5)

rf.model <- randomForest(label ~.,
                             data = tr,
                             trControl = tc,
                             ntree = 500)

rf.predict <- predict(rf.model, va)
confusionMatrix(rf.predict, va$label)

# Creating a boosted tree model for the engineered data

# set.seed(2718)
# intrain <- createDataPartition(new.train.features$label, p = 0.7, list = FALSE)
# tr <- new.train.features[intrain,]
# va <- new.train.features[-intrain,]

tc <- trainControl(method = "cv",
                   number = 5)

xgbGrid <- expand.grid(eta = c(0.3),
                       max_depth = 1,
                       nrounds = c(500,800),
                       gamma = 0,
                       colsample_bytree = 0.6,
                       min_child_weight = 1,
                       subsample = 1)

xgbtreemodel <- train(label ~.,
                      data = tr,
                      method = "xgbTree",
                      trControl = tc, 
                      tuneGrid = xgbGrid)

xg.predict <- predict(xgbtreemodel, va)
confusionMatrix(xg.predict, va$label)


# Creating a feedforward neural network model for the engineered data
 
k.train.x <- as.matrix(new.train.features[,-1])
k.train.y <- as.matrix(new.train.features[,c("label")])
set.seed(2718)
intrain <- createDataPartition(k.train.y, p = 0.7, list = FALSE)
k.val.x <- k.train.x[-intrain,]
k.val.y <- to_categorical(k.train.y[-intrain,])
k.train.x <- k.train.x[intrain,]
k.train.y <- to_categorical(k.train.y[intrain,])

k.model <- keras_model_sequential() %>%
        layer_dense(units = 512, activation = "relu", input_shape = ncol(k.train.x)) %>%
        layer_dropout(0.25) %>%
        layer_dense(units = 512, activation = "relu") %>%
        layer_dropout(0.25) %>%
        layer_dense(units = 512, activation = "relu") %>%
        layer_dropout(0.25) %>%
        layer_dense(units = 10, activation = "softmax")
k.model %>% compile(optimizer = "rmsprop",
                    loss = "categorical_crossentropy",
                    metrics = c("accuracy"))
k.history <- k.model %>% fit(k.train.x,
                             k.train.y,
                             epochs = 75,
                             batch_size = 512,
                             validation_data = list(k.val.x, k.val.y))

k.predict <- predict_classes(k.model, k.val.x)
confusionMatrix(as.matrix(new.train.features[-intrain,c("label")]), k.predict)

# Now we'll combine the results from the 3 models above into an aggregate model 

ens <- as.data.frame(cbind(va$label, k.predict, xg.predict, rf.predict))
names(ens) <- c("label", "keraspred", "xgpredict", "rfpredict")
ens$label <- as.factor(ens$label - 1)
ens$xgpredict <- ens$xgpredict - 1
ens$rfpredict <- ens$rfpredict - 1

set.seed(2718)
intrain <- createDataPartition(ens$label, p = 0.7, list = FALSE)
tr <- ens[intrain,]
va <- ens[-intrain,]

ens.model <- randomForest(label ~.,
                          data = tr,
                          mtry = 2, 
                          ntree = 100,
                          trControl = tc)

ens.predict <- predict(ens.model, va)
confusionMatrix(va$label, ens.predict)



rm(xgbGrid); rm(xgbtreemodel); rm(xg.predict); rm(rf.predict); rm(rf.model); rm(corr); rm(ens); rm(ens.model); rm(ens.predict)



# Then, for comparison purposes, we'll run a model on the combined data with both the original
# and new features
set.seed(2718)
intrain <- createDataPartition(original.train$label, p = 0.7, list = FALSE)
tr <- original.train[intrain,]
va <- original.train[-intrain,]

tc <- trainControl(method = "cv", 
                   number = 10)

rf.model <- train(label ~.,
                  data = tr,
                  method = "rf",
                  trControl = tc,
                  ntree = 500)

rf.predict <- predict(rf.model, va)
confusionMatrix(rf.predict, va$label)

# Save image

# Then, for comparison purposes, we'll run a model on the combined data with both the original
# and new features

set.seed(2718)
intrain <- createDataPartition(trainset$label, p = 0.7, list = FALSE)
tr <- trainset[intrain,]
va <- trainset[-intrain,]

tc <- trainControl(method = "cv", 
                   number = 10)

rf.model <- train(label ~.,
                  data = tr,
                  method = "rf",
                  trControl = tc,
                  ntree = 500)

rf.predict <- predict(rf.model, va)
confusionMatrix(rf.predict, va$label)

















# Creating a neural network with Keras

k.train.x <- as.matrix(new.train.features[,-1])
k.train.y <- as.matrix(new.train.features[,c("label")])
intrain <- createDataPartition(k.train.y, p = 0.7, list = FALSE)
k.val.x <- k.train.x[-intrain,]
k.val.y <- to_categorical(k.train.y[-intrain,])
k.train.x <- k.train.x[intrain,]
k.train.y <- to_categorical(k.train.y[intrain,])
k.test.x <- as.matrix(testset)
k.test.x <- scale(k.test.x)



k.model <- keras_model_sequential() %>%
                layer_dense(units = 512, activation = "relu", input_shape = ncol(k.train.x)) %>%
                layer_dropout(0.25) %>%
                layer_dense(units = 512, activation = "relu") %>%
                layer_dropout(0.25) %>%
                layer_dense(units = 10, activation = "softmax")
k.model %>% compile(optimizer = "rmsprop",
                    loss = "categorical_crossentropy",
                    metrics = c("accuracy"))
k.history <- k.model %>% fit(k.train.x,
                             k.train.y,
                             epochs = 250,
                             batch_size = 1024,
                             validation_data = list(k.val.x, k.val.y))
k.history
plot(k.history)
k.predict <- predict_classes(k.model, k.test.x)
table(predict_classes(k.model, k.test.x))






