package com.meeplehearth;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
public class MeepleBackendApplication {

	public static void main(String[] args) {
		SpringApplication.run(MeepleBackendApplication.class, args);
	}

}
