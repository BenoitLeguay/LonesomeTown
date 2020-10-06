import pygame


# define a main function
def main():
    # initialize the pygame module
    pygame.init()


    # create a surface on screen that has the size of 240 x 180
    screen = pygame.display.set_mode((240, 180))

    # define a variable to control the main loop
    running = True

    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False

        pygame.draw.rect(screen, (100,100,255),[5,5,100,100])

        pygame.display.flip()


#def display_characters(characters = []):
#    for character in characters:





# run the main function only if this module is executed as the main script
# (if you import this as a module then nothing is executed)
if __name__ == "__main__":
    # call the main function
    main()