//
//  AGAppDelegate.m
//  itunesRecentlyAddedAlbums
//
//  Created by Sheeley, John(jsheeley) on 3/16/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "AGAppDelegate.h"

@implementation AGAppDelegate

- (void) applicationDidFinishLaunching:(NSNotification *)aNotification
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults objectForKey:SETTINGS_KEY] == nil){
        NSDictionary *defaultSettings = [[NSDictionary alloc] initWithObjectsAndKeys:@"Music", SOURCE_PLAYLIST,
                                         NO_PLAYLIST, TO_ALBUM_PLAYLIST, NO_PLAYLIST, TO_SINGLE_PLAYLIST, @"5",
                                         MIN_SONGS_PER_ALBUM, @"10", MAX_ALBUMS, @"YES", CLEAR_TO_ALBUM_PLAYLIST,
                                         @"YES", CLEAR_TO_SINGLE_PLAYLIST, @"Never", REPEAT_ARRANGEMENT, nil];
        NSDictionary *domain = [[NSDictionary alloc] initWithObjectsAndKeys:defaultSettings, SETTINGS_KEY, nil];
        [defaults registerDefaults:domain];
        [defaults synchronize];
    }
    
    self.agItunes = [[AGItunes alloc] init];
    [self populateForm];
    [self observeNotifications];
}

- (IBAction) arrangeTracks: (id) sender
{    
    [self arrangeTracks];
}

- (IBAction) refreshPlaylists: (id) sender
{
    [self saveSettings];
    [self populateForm];
}

- (IBAction)updateRepeat:(id)sender
{
    [self toggleTimer];
    [self saveSettings];
}

- (AGRunConfig *) getRunConfig
{
    AGRunConfig *config = [[AGRunConfig alloc] init];
    config.fromPlaylist = [self.fromPlaylistPopUp titleOfSelectedItem];
    config.toPlaylistSingles = [self.toPlaylistSinglesPopUp titleOfSelectedItem];
    config.toPlaylistAlbums = [self.toPlaylistAlbumsPopUp titleOfSelectedItem];
    config.minTracksPerAlbum = (int)[[self.minSongPopUp titleOfSelectedItem] doubleValue];
    config.maxAlbumsToProcess = (int)[[self.maxAlbumPopUp titleOfSelectedItem] doubleValue];
    config.doClearSinglesPlaylist = ([self.clearSinglesPlaylistButton state] == NSOnState) ? @"YES" : @"NO";
    config.doClearAlbumsPlaylist = ([self.clearAlbumsPlaylistButton state] == NSOnState) ? @"YES" : @"NO";
    config.maxTracksToIngest = 1000;
    return config;
}

- (void) arrangeTracks
{
    [self.goButton setEnabled:NO];
    [self.spinner startAnimation:self.goButton];
    [self.outputField setString:@""];
    dispatch_queue_t queue = dispatch_queue_create("music processing", NULL);
    dispatch_async(queue, ^{
        [self saveSettings];
        [_agItunes setConfig:[self getRunConfig]];
        [_agItunes arrangeSongs];
//         : ^(AGRunData *output) {
//            dispatch_async(dispatch_get_main_queue(), ^{
//                [self.outputField setString:[output toString]];
//            });
//        }];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.goButton setEnabled:YES];
            [self.spinner stopAnimation:self.goButton];
            [self toggleTimer];
        });        
    });
    dispatch_release(queue);
}

-(void) saveSettings
{
    NSString *fromPlaylistName = [self.fromPlaylistPopUp titleOfSelectedItem];
    NSString *toPlaylistNameSingles = [self.toPlaylistSinglesPopUp titleOfSelectedItem];
    NSString *toPlaylistNameAlbums = [self.toPlaylistAlbumsPopUp titleOfSelectedItem];
    NSString *minTracks = [self.minSongPopUp titleOfSelectedItem];
    NSString *maxAlbums = [self.maxAlbumPopUp titleOfSelectedItem];
    NSString *doClearSinglesPlaylist = ([self.clearSinglesPlaylistButton state] == NSOnState) ? @"YES" : @"NO";
    NSString *doClearAlbumsPlaylist = ([self.clearAlbumsPlaylistButton state] == NSOnState) ? @"YES" : @"NO";
    NSString *interval = [self.repeatButton titleOfSelectedItem];

    NSMutableDictionary *formData = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                                     fromPlaylistName,SOURCE_PLAYLIST, toPlaylistNameAlbums, TO_ALBUM_PLAYLIST,
                                     toPlaylistNameSingles, TO_SINGLE_PLAYLIST, minTracks, MIN_SONGS_PER_ALBUM, 
                                     maxAlbums, MAX_ALBUMS, doClearAlbumsPlaylist, CLEAR_TO_ALBUM_PLAYLIST, 
                                     doClearSinglesPlaylist, CLEAR_TO_SINGLE_PLAYLIST, interval, REPEAT_ARRANGEMENT, nil];
    [[NSUserDefaults standardUserDefaults] setValue:formData forKey:SETTINGS_KEY];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
 
- (void) loadSettings
{
    NSDictionary *settings = [[NSUserDefaults standardUserDefaults] objectForKey:SETTINGS_KEY];
    if(settings != nil){
        NSString *fromPlaylistName = [settings objectForKey:SOURCE_PLAYLIST];
        NSString *toPlaylistNameSingles = [settings objectForKey:TO_SINGLE_PLAYLIST];
        NSString *toPlaylistNameAlbums = [settings objectForKey:TO_ALBUM_PLAYLIST];
        NSString *minTracks = [settings objectForKey:MIN_SONGS_PER_ALBUM];
        NSString *maxAlbums = [settings objectForKey: MAX_ALBUMS];
        bool doClearSinglesPlaylist = [settings objectForKey:CLEAR_TO_SINGLE_PLAYLIST];
        bool doClearAlbumsPlaylist = [settings objectForKey:CLEAR_TO_ALBUM_PLAYLIST];
        NSString *interval = [settings objectForKey:REPEAT_ARRANGEMENT];
    
        [self.fromPlaylistPopUp selectItemWithTitle:fromPlaylistName];
        [self.toPlaylistSinglesPopUp selectItemWithTitle:toPlaylistNameSingles];
        [self.toPlaylistAlbumsPopUp selectItemWithTitle:toPlaylistNameAlbums];
        [self.minSongPopUp selectItemWithTitle:minTracks];
        [self.maxAlbumPopUp selectItemWithTitle:maxAlbums];
        [self.minSongPopUp selectItemWithTitle:minTracks];
        [self.clearSinglesPlaylistButton setState:doClearSinglesPlaylist];
        [self.clearAlbumsPlaylistButton setState:doClearAlbumsPlaylist];
        [self.repeatButton selectItemWithTitle:interval];
    }
}

- (void) populateForm
{
    dispatch_queue_t queue = dispatch_queue_create("music processing", NULL);
    [self.spinner startAnimation:nil];
    dispatch_async(queue, ^{
        SBElementArray *availablePlaylists = [self.agItunes getItunesPlaylists];
        
        [self.toPlaylistSinglesPopUp addItemWithTitle:NO_PLAYLIST];
        [self.toPlaylistAlbumsPopUp addItemWithTitle:NO_PLAYLIST];
        [self.fromPlaylistPopUp addItemWithTitle:NO_PLAYLIST];
        if(availablePlaylists != nil){
            for(iTunesUserPlaylist *playlist in availablePlaylists){
                NSString *pName = [playlist name];
                if([playlist specialKind] == iTunesESpKNone && ![playlist smart]){
                    [[self toPlaylistAlbumsPopUp] addItemWithTitle:pName];
                    [[self toPlaylistSinglesPopUp] addItemWithTitle:pName];
                }            
                [[self fromPlaylistPopUp] addItemWithTitle:pName];
            }
        }
        
        for(int i = 0; i<11; i++){
            NSString *is = [NSString stringWithFormat:@"%d", (i+2)];
            [self.maxAlbumPopUp addItemWithTitle:is];
        }
        
        for(int i = 0; i<9; i++){
            NSString *is = [NSString stringWithFormat:@"%d", (i+2)];
            [self.minSongPopUp addItemWithTitle:is];
        }
        
        [self.repeatButton insertItemWithTitle:@"Never" atIndex:0];
        [self.repeatButton insertItemWithTitle:@"Hourly" atIndex:1];
        [self.repeatButton insertItemWithTitle:@"Daily" atIndex:2];
        [self.repeatButton insertItemWithTitle:@"Weekly" atIndex:3];
//        [self.repeatButton insertItemWithTitle:@"Test" atIndex:4];

        dispatch_async(dispatch_get_main_queue(), ^{
            [self loadSettings];
            [self.spinner stopAnimation:nil];
            [self toggleTimer];
        });        
    });
    dispatch_release(queue);
}

- (void) toggleTimer
{
    bool setTimer = true;
    NSString *interval = [self.repeatButton titleOfSelectedItem];
    int secsInterval = 0;
    if([@"Hourly" isEqualToString:interval]){
        secsInterval = 60 * 60;
    } else if([@"Daily" isEqualToString:interval]){
        secsInterval *= 24;
    } else if([@"Weekly" isEqualToString:interval]){
        secsInterval *= 24 * 7;
    } else {
        setTimer = false;
    }
    
    if(setTimer && secsInterval > 0){
        if(self.timer == nil || [self.timer timeInterval] != secsInterval){
            if(self.timer != nil){
                [self.timer invalidate];
            }
            self.timer = [NSTimer scheduledTimerWithTimeInterval:secsInterval
                                                          target:self
                                                        selector:@selector(arrangeTracks)
                                                        userInfo:nil
                                                         repeats:YES];
        }
    } else if(self.timer != nil){
        [self.timer invalidate];
        self.timer = nil;
    }
}

-(void) observeNotifications
{
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    NSOperationQueue *mainQueue = [NSOperationQueue mainQueue];
    [center addObserverForName:@"output" object:nil queue:mainQueue usingBlock:^(NSNotification *note) {
        id payload = [[note userInfo] valueForKey:@"output"];
        if([payload isKindOfClass:[NSString class]]){
            NSString *currVal = [self.outputField string];
            if([currVal length] > 0){
                currVal = [currVal stringByAppendingString:@"\n"];
            }
            NSString *output = [currVal stringByAppendingString:payload];
            [self.outputField setString:output];
        }
    }];
}
@end
