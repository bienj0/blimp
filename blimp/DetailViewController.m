//
//  DetailViewController.m
//  blimp
//
//  Created by Robin van 't Slot on 09-10-14.
//  Copyright (c) 2014 BrickInc. All rights reserved.
//

#import <Parse/Parse.h>
#import "DetailViewController.h"
#import "UIImage+StackBlur.h"
#import "YTPlayerView.h"

@interface DetailViewController ()

@property (strong, nonatomic) IBOutlet UILabel *movieTitleLabel;
@property (strong, nonatomic) IBOutlet UILabel *movieTagLineLabel;
@property (strong, nonatomic) IBOutlet UILabel *movieGenreLabel;
@property (strong, nonatomic) IBOutlet UILabel *movieRuntimeLabel;
@property (strong, nonatomic) IBOutlet UILabel *movieBudgetLabel;
@property (strong, nonatomic) IBOutlet UILabel *movieRevenue;
@property (strong, nonatomic) IBOutlet UILabel *movieOverViewLabel;

@property (strong, nonatomic) IBOutlet UIScrollView *scrollView;
@property(nonatomic, strong) IBOutlet YTPlayerView *playerView;

@property (strong, nonatomic) NSCache *imageCache;
@property (strong, nonatomic) NSOperationQueue *imageDownloadingQueue;
@property (strong, nonatomic) NSString *youtubeID;

@end

@implementation DetailViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.imageDownloadingQueue = [[NSOperationQueue alloc] init];
    self.imageDownloadingQueue.maxConcurrentOperationCount = 4;
    self.imageCache = [[NSCache alloc] init];
    
    [self setupView];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
 #pragma mark - Navigation
 
 // In a storyboard-based application, you will often want to do a little preparation before navigation
 - (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
 // Get the new view controller using [segue destinationViewController].
 // Pass the selected object to the new view controller.
 }
 */

#pragma mark - IB Actions
- (IBAction)saveButtonPressed:(UIBarButtonItem *)sender
{
    [self saveMovie];
}


#pragma mark - Helper Methods

- (void)setupView
{
    //setup ScrollView
    [self.view addSubview:self.scrollView];
    self.scrollView.contentSize = CGSizeMake(self.view.bounds.size.width, self.view.bounds.size.height * 1.25);
    
    //set movieposter
    NSString *moviePosterPath = self.movie[@"poster_path"];
    NSString *moviePosterURL = [NSString stringWithFormat:@"http://image.tmdb.org/t/p/w500/%@", moviePosterPath];
    
    UIImage *cachedImage = [self.imageCache objectForKey:moviePosterURL];
    if (cachedImage) {
        [self.view setBackgroundColor:[UIColor colorWithPatternImage:cachedImage]];
    }
    else{
        [self.imageDownloadingQueue addOperationWithBlock:^{
            NSURL *posterURL = [NSURL URLWithString:moviePosterURL];
            NSData *imageData = [NSData dataWithContentsOfURL:posterURL];
            UIImage *image = nil;
            if (imageData) {
                image = [UIImage imageWithData:imageData];
                UIImage *blurImage = [image stackBlur:8];
                if (blurImage) {
                    [self.imageCache setObject:blurImage forKey:moviePosterURL];
                    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                        [self.view setBackgroundColor:[UIColor colorWithPatternImage:blurImage]];
                    }];
                }
            }
        }];
    }
    
    //get movie info by ID;
    NSString *movieID = [NSString stringWithFormat:@"%@", self.movie[@"id"]];
    NSURL *movieInfoURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://api.themoviedb.org/3/movie/%@?api_key=e8e5ab2c71786482e03bb518c67c08ab&append_to_response=releases,trailers", movieID]];
    NSURLRequest *request = [NSURLRequest requestWithURL:movieInfoURL];
    
    dispatch_queue_t downloadQueue = dispatch_queue_create("download movie info queue", NULL);
    dispatch_async(downloadQueue, ^{
        NSData *movieDataJSON = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
        NSString *movieDataString = [[NSString alloc] initWithData:movieDataJSON encoding:NSUTF8StringEncoding];
        NSData  *movieData = [movieDataString dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *movieDataByID = [NSJSONSerialization JSONObjectWithData:movieData options:0 error:nil];
        NSDictionary *movieByID = (NSDictionary *)movieDataByID;
        NSLog(@"%@", movieByID);
        NSArray *movieGenres = movieByID[@"genres"];
        
        NSMutableArray *genre = [[NSMutableArray alloc] init];
        for (int i = 0; i < [movieGenres count]; i++) {
            [genre addObject:movieByID[@"genres"][i][@"name"]];
        }
        
        NSDictionary *youtubeTrailerID = movieByID[@"trailers"][@"youtube"];
        BOOL isEmpty = ([youtubeTrailerID count] == 0);
        if (isEmpty != YES) {
            self.youtubeID = movieByID[@"trailers"][@"youtube"][0][@"source"];
        }else{
            self.youtubeID = @"HzTdxiixjrk";
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            [self.playerView loadWithVideoId:self.youtubeID];
            
            self.movieTitleLabel.text = self.movie[@"original_title"];
            self.movieTitleLabel.adjustsFontSizeToFitWidth = YES;
            NSString *stringOfMovieGenres = [genre componentsJoinedByString:@", "];
            
            NSString *movieTagline = movieByID[@"tagline"];
            if ([movieTagline length] != 0) {
                self.movieTagLineLabel.text = movieByID[@"tagline"];
            }else{
                self.movieTagLineLabel.text = @"No tagline found.";
            }
            
            self.movieGenreLabel.text = stringOfMovieGenres;
            self.movieRuntimeLabel.text = [NSString stringWithFormat:@"%@", movieByID[@"runtime"]];
            self.movieBudgetLabel.text = [NSString stringWithFormat:@"%@", movieByID[@"budget"]];
            self.movieRevenue.text =  [NSString stringWithFormat:@"%@", movieByID[@"revenue"]];
            self.movieOverViewLabel.text = movieByID[@"overview"];
        });
    });
    
}

- (void)saveMovie
{
    PFQuery *query = [PFQuery queryWithClassName:@"Movie"];
    [query whereKey:@"tmdb_id" equalTo:self.movie[@"id"]];
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        if (!error) {
            if ([objects count] > 0) {
                NSLog(@"Movie is already in database");
                
                PFObject *watchlist = [PFObject objectWithClassName:@"WatchList"];
                NSString *objectId = [NSString stringWithFormat:@"%@", [objects[0] objectId]];
                [query getObjectInBackgroundWithId:objectId block:^(PFObject *object, NSError *error) {
                    PFObject *myMovie = object;
                    
                    PFQuery *queryForWatchlist = [PFQuery queryWithClassName:@"WatchList"];
                    [queryForWatchlist whereKey:@"fromUser" equalTo:[PFUser currentUser]];
                    [queryForWatchlist whereKey:@"withMovie" equalTo:myMovie];
                    [queryForWatchlist findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
                        if (!error) {
                            if ([objects count] > 0) {
                                NSLog(@"Movie already on watchlist");
                            }
                            else if([objects count] == 0){
                                watchlist[@"fromUser"] = [PFUser currentUser];
                                watchlist[@"withMovie"] = myMovie;
                                [watchlist saveInBackground];
                            }
                        }else{
                            NSLog(@"%@", error);
                        }
                            
                    }];
                }];
                
            }else if([objects count] == 0){
                PFObject *movie = [PFObject objectWithClassName:@"Movie"];
                movie[@"tmdb_id"] = self.movie[@"id"];
                movie[@"original_title"] = self.movie[@"original_title"];
                movie[@"poster_path"] = self.movie[@"poster_path"];
                movie[@"backdrop_path"] = self.movie[@"backdrop_path"];
                movie[@"youtube_id"] = self.youtubeID;
                [movie saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
                    if (succeeded) {
                        PFObject *watchlist = [PFObject objectWithClassName:@"WatchList"];
                        watchlist[@"fromUser"] = [PFUser currentUser];
                        watchlist[@"withMovie"] = movie;
                        [watchlist saveInBackground];
                    }else{
                        NSLog(@"%@", error);
                    }
                    
                }];
            }
        }else{
            NSLog(@"%@", error);
        }
    }];
    
}



@end
