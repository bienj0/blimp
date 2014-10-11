//
//  ViewController.m
//  blimp
//
//  Created by Robin van 't Slot on 09-10-14.
//  Copyright (c) 2014 BrickInc. All rights reserved.
//

#import "ViewController.h"
#import "DetailViewController.h"

@interface ViewController () <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate>

@property (strong, nonatomic) IBOutlet UITableView *tableView;

@property (strong, nonatomic) NSMutableArray *moviesFromResponse;
@property (strong, nonatomic) NSOperationQueue *imageDownloadingQueue;
@property (strong, nonatomic) NSCache *imageCache;

@end

@implementation ViewController

-(NSMutableArray *)moviesFromResponse
{
    if (!_moviesFromResponse) {
        _moviesFromResponse = [[NSMutableArray alloc] init];
    }
    return _moviesFromResponse;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.imageDownloadingQueue = [[NSOperationQueue alloc] init];
    self.imageDownloadingQueue.maxConcurrentOperationCount = 4;
    
    self.imageCache = [[NSCache alloc] init];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    
    self.tableView.backgroundView = nil;
    self.tableView.backgroundColor = [UIColor colorWithRed:28/255.0 green:28/255.0 blue:28/255.0 alpha:0.9];
    
    UISearchBar *searchBar = [[UISearchBar alloc] init];
    self.navigationItem.titleView = searchBar;
    searchBar.delegate = self;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Navigation

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([sender isKindOfClass:[UITableViewCell class]]) {
        if ([segue.destinationViewController isKindOfClass:[DetailViewController class]]) {
            DetailViewController *detailVC = segue.destinationViewController;
            NSIndexPath *path = [self.tableView indexPathForCell:sender];
            detailVC.movie =  self.moviesFromResponse[path.row];
        }
    }
    
}

#pragma mark - UITableView Delegate methods

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.moviesFromResponse count];
}

-(void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    cell.textLabel.textColor = [UIColor whiteColor];
    cell.textLabel.font = [UIFont fontWithName:@"HelveticaNeue-Light" size:20];
    cell.textLabel.adjustsFontSizeToFitWidth = YES;
    
    cell.detailTextLabel.textColor = [UIColor whiteColor];
    cell.detailTextLabel.font = [UIFont fontWithName:@"HelveticaNeue-Light" size:12];
    
    NSDictionary *movie = self.moviesFromResponse[indexPath.row];
    NSString *moviePoster = movie[@"backdrop_path"];
    NSString *pictureURL = [NSString stringWithFormat:@"http://image.tmdb.org/t/p/w780/%@", moviePoster];
    UIImage *cachedImage = [self.imageCache objectForKey:pictureURL];
    if (cachedImage) {
        [cell setBackgroundColor:[UIColor colorWithPatternImage:cachedImage]];
    }
    else{
        [self.imageDownloadingQueue addOperationWithBlock:^{
            NSURL *posterURL = [NSURL URLWithString:pictureURL];
            NSData *imageData = [NSData dataWithContentsOfURL:posterURL];
            UIImage *image = nil;
            if (imageData) {
                image = [UIImage imageWithData:imageData scale:3];
                if (image) {
                    [self.imageCache setObject:image forKey:pictureURL];
                    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                        UITableViewCell *updateCell = [tableView cellForRowAtIndexPath:indexPath];
                        if (updateCell){
                            [cell setBackgroundColor:[UIColor colorWithPatternImage:image]];
                        }
                    }];
                }
            }
        }];
    }
    
}

#pragma mark - UITableView Datasource methods

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    
    NSDictionary *movie = self.moviesFromResponse[indexPath.row];
    if (cell == nil) {
        cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    }
    cell.textLabel.text = movie[@"original_title"];
    cell.detailTextLabel.text = movie[@"release_date"];
    cell.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"cell_background.png"]];
    
    return cell;
}


#pragma mark - UISearchBar Delegate

- (BOOL)searchBarShouldBeginEditing:(UISearchBar *)searchBar
{
    searchBar.showsScopeBar = YES;
    [searchBar sizeToFit];
    [searchBar setShowsCancelButton:YES animated:YES];
    
    return YES;
}

- (BOOL)searchBarShouldEndEditing:(UISearchBar *)searchBar
{
    searchBar.showsScopeBar = NO;
    [searchBar sizeToFit];
    [searchBar setShowsCancelButton:NO animated:YES];
    
    return YES;
}

-(void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
    [self searchBarShouldEndEditing:searchBar];
    searchBar.text = nil;
    [self.moviesFromResponse removeAllObjects];
    [self.tableView reloadData];
    [searchBar resignFirstResponder];
}

-(void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    NSString *searchBarText = searchBar.text;
    NSString *query = [searchBarText stringByReplacingOccurrencesOfString:@" " withString:@"%20"];
    if (self.moviesFromResponse != nil) [self.moviesFromResponse removeAllObjects];
    [self movieSearch:query];
    [self.tableView reloadData];
}

#pragma mark - Helper Methods

-(void)movieSearch:(NSString *)query
{
    NSURL *movieURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://api.themoviedb.org/3/search/movie?api_key=e8e5ab2c71786482e03bb518c67c08ab&query=%@", query]];
    NSURLRequest *request = [NSURLRequest requestWithURL:movieURL];
    
    
    NSData *movieJSON = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
    NSString *jsonString = [[NSString alloc] initWithData:movieJSON encoding:NSUTF8StringEncoding];
    NSData *data = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    NSDictionary *movies = (NSDictionary *)json;
    
    NSArray *queryResult = movies[@"results"];
    
    NSMutableArray *queryArray = [[NSMutableArray alloc] init];
    for (NSDictionary *movie in queryResult){
        [queryArray addObject:movie];
    }
    
    NSSortDescriptor *sortDescriptor;
    sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"release_date"
                                                 ascending:NO];
    NSMutableArray *sortDescriptors = [NSMutableArray arrayWithObject:sortDescriptor];
    NSArray *responseMovies = [queryArray sortedArrayUsingDescriptors:sortDescriptors];
    self.moviesFromResponse = [[NSMutableArray alloc] initWithArray:responseMovies];
}

@end
